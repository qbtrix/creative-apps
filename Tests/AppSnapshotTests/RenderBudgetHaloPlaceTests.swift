// RenderBudgetHaloPlaceTests.swift (placed-images PH-u): the ⌥-drag focus pan's render budget on the real Halo
// window through the harness (RenderBudgetHarness.swift). `three-layers` with a 4000 x 3000 JPEG on Background
// (built from values: the place commands run in PH-6), Background selected; 120 ⌥-dragged samples at 120 Hz over
// the viewer pan the picture's focus. Budget: the window's body runs at most 3 times; each sample shows through
// HaloLiveEdit and the release sends one `place.focus`. The packet's p95 ≤ 8 ms is printed, not gated (timing
// gates live in Tests/perf-suites.txt). The harness sends events with no modifiers, so this suite builds its own
// with ⌥ held. Off until PH-6 builds `place.focus`. Nested in
// BodyCountSuites, as every suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import HaloModel
import SuiteKernel
import SwiftUI
import Testing

@testable import HaloApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetHaloPlaceTests {
        @Test(.disabled("waits on PH-6's place.focus"), .timeLimit(.minutes(3)))
        func focusDragInThreeBodies() async throws {
            var document = try #require(HaloFixtures.project("three-layers"))
            let l = try #require(document.compositions.first?.layers.firstIndex { $0.name == "Background" })
            document.compositions[0].layers[l].placedAsset = PlacedAsset(
                id: "photo", name: "photo-4000x3000.jpg", format: .jpeg, natural: Size(width: 4000, height: 3000),
                data: try HaloPlaceSnapshots.jpeg(width: 4000, height: 3000))
            var project = HaloProject(services: .fake, document: document)
            project.selectLayer(document.compositions[0].layers[l].id)
            #expect(project.placedSelection != nil, "Background shows the photo")
            let w = RenderBudgetWindow(HaloWindow(model: project).environment(\.haloViewerTakesActivationClicks, true))
            defer { w.close() }
            try await w.settle(500)
            let canvas = try #require(await w.element("halo.viewer.canvas"), "no halo.viewer.canvas")
            let start = CGPoint(x: canvas.midX, y: canvas.midY)
            let step = try await w.measure(
                "halo place focus ⌥-drag, 120 samples", bodies: HaloWindowPlaybackTests.windowBodies
            ) {
                w.timed { Self.send(.leftMouseDown, at: start, in: w.window) }
                try await w.ticks(120) { i in
                    Self.send(.leftMouseDragged, at: CGPoint(x: start.x, y: start.y + Double(i)), in: w.window)
                }
                w.timed { Self.send(.leftMouseUp, at: CGPoint(x: start.x, y: start.y + 120), in: w.window) }
            }
            print("PLACE-FOCUS \(step) | packet budget: p95 ≤ 8 ms (measured \(step.p95) ms)")
            #expect(step.steps >= 120, "the drag sent \(step.steps) steps")
            // Target: 3 (the release's one commit, plus the live preview's start and end).
            expectBodies(step, atMost: 3, target: 3)
        }

        /// A mouse event at `point` (window coordinates) with ⌥ held.
        private static func send(_ kind: NSEvent.EventType, at point: CGPoint, in window: NSWindow) {
            guard let event = NSEvent.mouseEvent(
                with: kind, location: point, modifierFlags: [.option], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)
            else { Issue.record("no \(kind) event"); return }
            window.sendEvent(event)
        }
    }
}
#endif
