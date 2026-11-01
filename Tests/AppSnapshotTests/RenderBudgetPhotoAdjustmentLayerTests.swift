// RenderBudgetPhotoAdjustmentLayerTests.swift (#2875, PJ-P2's adjustment series on the render budget harness):
// what an inspector Exposure scrub costs the real Photo window on `large` (4000 x 3000, three layers). It
// hosts PhotoWindow, adds an Exposure adjustment layer (the journey's Layer > New Adjustment Layer), and drags
// that layer's Exposure bar slider rightward in 120 events at 120 Hz, as the journey's click-and-drag does (an
// accessibility increment is a whole gesture, change and end, so it can't show a scrub's cost); the
// whole-image Exposure slider gets the same drag on its own window. Each sample runs on the window's live copy
// (LiveTransformCopy+Kernel.swift), as a tone row's does, so the editor body runs at most 3 times, counted on
// a SuiteUI BodyTally in this window's environment (debug only). The release ends the gesture and takes the
// copy back, so the test then reads the workspace, waiting up to 2 s for the raised value to land. The step
// p95 (budget 16 ms) is printed, never asserted, until the supervisor lists the suite in
// Tests/perf-suites.txt. Nested in BodyCountSuites, as every suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import PhotoModel
import SuiteImaging
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetPhotoAdjustmentLayerTests {
        static let samples = 120

        @Test(.timeLimit(.minutes(2))) func layerExposureScrubInThreeBodies() async throws {
            var model = try PhotoWorkspace.fixture(.large)
            model.addAdjustmentLayer(.exposure)
            guard case .layer(let id, _) = model.adjustTarget else {
                Issue.record("New Adjustment Layer > Exposure didn't select an adjustment layer")
                return
            }
            let after = try await scrub(model, "photo adjustment layer exposure scrub on large, 120 steps") {
                if case .adjustment(let settings) = $0.layers.first(where: { $0.id == id })?.kind {
                    return settings.exposure
                }
                return nil
            }
            #expect(after?.undoActionName == "Undo Exposure", "the last step is \(after?.undoActionName ?? "none")")
            #expect(after?.adjustments == AdjustmentSettings(), "the layer's scrub changed the whole image's adjustments")
        }

        @Test(.timeLimit(.minutes(2))) func imageExposureScrubInThreeBodies() async throws {
            let model = try PhotoWorkspace.fixture(.large)
            let after = try await scrub(model, "photo image exposure scrub on large, 120 steps") { $0.adjustments.exposure }
            #expect(after?.undoActionName == "Undo Exposure", "the last step is \(after?.undoActionName ?? "none")")
        }

        /// Hosts `model`'s window, drags its Exposure slider rightward in `samples` events, prints and checks the
        /// cost, and returns the workspace once `exposure` of it rises above 0 (nil when it never does).
        private func scrub(
            _ model: PhotoWorkspace, _ name: String, exposure: @escaping (PhotoWorkspace) -> Float?
        ) async throws -> PhotoWorkspace? {
            let tally = BodyTally()
            let w = RenderBudgetWindow(PhotoWindow(model: model).environment(\.bodyTally, tally))
            defer { w.close() }
            let bodies = { RenderBudgetPhotoToneTests.bodies(tally) }
            let edited = try #require(await w.first(PhotoWindowEditedView.self))
            try await w.settle(untilStable: bodies)
            let slider = try #require(Self.slider("Exposure", in: w.host), "no Exposure slider in the inspector")
            let bar = w.window.convertFromScreen(try #require(slider.accessibilityFrame?(), "the Exposure slider has no frame"))
            let start = CGPoint(x: bar.minX + bar.width * 0.1, y: bar.midY)
            let step = try await w.measure(name, bodies: bodies) {
                try await w.drag(from: start, by: CGVector(dx: bar.width * 0.8, dy: 0), samples: Self.samples)
            }
            print("RENDER-BUDGET \(name) p95 \(String(format: "%.2f", step.p95)) ms (budget 16, print-only)")
            #expect(step.steps >= Self.samples, "\(step)")
            let after = await RenderBudgetPhotoTransformTests.landed(edited) { (exposure($0) ?? 0) > 0 }
            let reached: Float? = after.flatMap(exposure)
            #expect(after != nil, "the drag left Exposure at \(String(describing: reached))")
            expectBodies(step, atMost: 3, target: 3)
            return after
        }

        /// The first slider labelled `label` in `root`'s accessibility tree.
        static func slider(_ label: String, in root: NSView) -> AnyObject? {
            var seen = Set<ObjectIdentifier>()
            func find(_ element: Any, _ depth: Int) -> AnyObject? {
                let node = element as AnyObject
                guard seen.insert(ObjectIdentifier(node)).inserted, depth < 60 else { return nil }
                if (node.accessibilityRole?() ?? nil) == .slider, (node.accessibilityLabel?() ?? nil) == label { return node }
                var children = (node.accessibilityChildren?() ?? nil) ?? []
                if let view = node as? NSView { children += view.subviews }
                for child in children {
                    if let found = find(child, depth + 1) { return found }
                }
                return nil
            }
            return find(root, 0)
        }
    }
}
#endif
