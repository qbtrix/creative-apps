// RenderBudgetEditorKernelStrokeTests.swift: what the editor-kernel chrome's
// stroke pad costs in a real 1280 x 820 window (editor-kernel packet, Quality
// tests; EK-31). A 120-sample drag across the pad, paced by SuiteStrokePacer,
// runs at most 1 window body: the samples stay in the pad's own state, so the
// window that holds it never reruns. The pad opts in to activation clicks, as
// a test process's every press is one. Nested in BodyCountSuites: it reads a
// global body counter. macOS only.
import AppKit
import SwiftUI
import Testing

@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetEditorKernelStrokeTests {
        @Test(.timeLimit(.minutes(2))) func testStrokePadBodies() async throws {
            let w = RenderBudgetWindow(StrokePadBudgetHost())
            defer { w.close() }
            let bodies = { () -> Int? in
                #if DEBUG
                return StrokePadBudgetHost.bodyRuns
                #else
                return nil
                #endif
            }
            try await w.settle(untilStable: bodies)
            let pad = try #require(await w.element("suite.gallery.stroke-pad"), "no stroke pad (suite.gallery.stroke-pad)")
            let start = CGPoint(x: pad.minX + 20, y: pad.midY)
            let step = try await w.measure("editor-kernel stroke pad, 120 samples", bodies: bodies) {
                try await w.drag(from: start, by: CGVector(dx: pad.width - 40, dy: 0))
            }
            // The pad's samples never reach the window. Target: 0.
            expectBodies(step, atMost: 1, target: 0)
            let drawn = await strokes(in: w)
            #expect(drawn == "1 strokes", "the drag drew no stroke on the pad: \(drawn ?? "no probe")")
        }

        /// The pad's stroke count ("N strokes"), waiting up to two seconds for the drag to show. It is read
        /// from the pad's probe, as AppKit hands the pad's own SwiftUI value back as nil (#262).
        private func strokes(in w: RenderBudgetWindow<StrokePadBudgetHost>) async -> String? {
            var label: String?
            for _ in 0..<100 {
                label = w.label("suite.gallery.stroke-pad.strokes")
                if label == "1 strokes" { return label }
                try? await Task.sleep(for: .milliseconds(20))
            }
            return label
        }
    }
}

/// The window around the stroke pad, counting its own bodies: the window bodies the budget counts.
private struct StrokePadBudgetHost: View {
    @MainActor static var bodyRuns = 0

    var body: some View {
        let _ = Self.bodyRuns += 1
        GalleryStrokePad()
            .allowsWindowActivationEvents()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
