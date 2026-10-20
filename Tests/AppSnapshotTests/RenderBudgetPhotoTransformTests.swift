// RenderBudgetPhotoTransformTests.swift (transform PT-7, quality row "render:
// 120-sample corner drag on a 12 MP layer, draft preview"): what dragging Free
// Transform's bottom-right corner costs the real Photo window, on the render
// budget harness (RenderBudgetHarness.swift). It hosts PhotoWindow on the
// `large` fixture (4000 x 3000, Noise selected), starts Free Transform, and
// sends 120 `.set` samples of one drag token at 120 Hz, each growing the
// draft's box 4 x 3 px from its top-left, the way TransformOverlay sends a corner
// drag (the harness can't press SuiteUI's handles: a test process's presses
// are window-activation clicks, which their drag gesture ignores). Spec: the
// draft previews every sample in at most 3 PhotoEditor bodies (target 1).
// Waits on PT-5: on PT-1's stubs every sample refuses. Step times
// are reported, not judged here. Nested in BodyCountSuites: it reads a
// process-global body counter. macOS only.
import AppKit
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetPhotoTransformTests {
        @Test(.disabled("waits on PT-5"), .timeLimit(.minutes(2))) func cornerDragInThreeBodies() async throws {
            var open = try PhotoWorkspace.fixture(.large)
            open.selectTool(.move)
            let w = RenderBudgetWindow(PhotoWindow(model: open))
            defer { w.close() }
            let canvas = try #require(await w.first(CanvasHostView.self))
            for _ in 0..<600 where !BodyCountSuites.PhotoZoomBudgetTests.shows(canvas) {
                try await Task.sleep(for: .milliseconds(50))
            }
            let edited = try #require(await w.first(PhotoWindowEditedView.self))
            let send = try #require(edited.send)
            send(.transform(.begin))
            try await w.settle(untilStable: PhotoWindowStrokeTests.editorBodies)
            let start = try #require(edited.workspace?.transformSelection, "Free Transform put no draft up")

            let token = UUID().uuidString
            let bodies = PhotoWindowStrokeTests.editorBodies
            let step = try await w.measure("photo free transform corner drag, 120 samples", bodies: bodies) {
                try await w.ticks(120) { i in
                    var next = start
                    next.box = Rect(minX: start.box.minX, minY: start.box.minY,
                                    maxX: start.box.maxX + Double(i * 4), maxY: start.box.maxY + Double(i * 3))
                    send(.transform(.kernel(.set(next, drag: token))))
                }
            }
            let after = try #require(edited.workspace)
            #expect(after.transformSelection?.box.maxX == start.box.maxX + 480, "the draft missed samples: \(step)")
            expectBodies(step, atMost: 3, target: 1)
        }
    }
}
