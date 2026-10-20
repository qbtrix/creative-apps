// RenderBudgetPhotoEyedropperTests.swift (eyedropper PE-4): what the
// Eyedropper's loupe costs the real Photo window, on the render budget harness
// (RenderBudgetHarness.swift). It hosts PhotoWindow on the `large` fixture
// (4000 x 3000, 12 MP) with the Eyedropper chosen and moves the pointer 120
// samples at 120 Hz across the canvas, as a hand's hover does. The pointer is
// PhotoCanvas's own state and only PhotoCanvasOverlay's PhotoSampleLoupe reads
// it, so PhotoEditor's body (a debug-only counter) runs at most 3 times.
// `loupeTrackTiming` prints the step p95 (budget 16 ms, a 60 Hz frame) and
// asserts nothing on time until the supervisor lists it in Tests/perf-suites.txt. Nested in BodyCountSuites, as every suite
// that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import PhotoModel
import SuiteUI
import SwiftUI
import Testing

@testable import PhotoApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetPhotoEyedropperTests {
        @Test(.timeLimit(.minutes(2))) func loupeTrackInThreeBodies() async throws {
            let (track, moves) = try await Self.run()
            #expect(moves == 120, "the pointer moved \(moves) of 120 times")
            // The pointer is read only by the loupe's layer: the editor's body never runs. Budget 3, target 0.
            expectBodies(track, atMost: 3, target: 0)
        }

        @Test(.timeLimit(.minutes(2))) func loupeTrackTiming() async throws {
            let (track, moves) = try await Self.run()
            // Print-only until the supervisor lists this test in Tests/perf-suites.txt: a step-time
            // assertion in the gate can go red on a loaded runner. Budget p95 16 ms, target 8.3 ms.
            print("RENDER-BUDGET photo eyedropper loupe track p95 \(String(format: "%.2f", track.p95)) ms (budget 16, target 8.3)")
            #expect(moves == 120, "the pointer moved \(moves) of 120 times")
        }

        /// 120 pointer moves over the hosted window's canvas, left to right across its middle.
        static func run() async throws -> (track: RenderStep, moves: Int) {
            var open = try PhotoWorkspace.fixture(.large)
            open.selectTool(.eyedropper)
            #expect(open.showsSampleLoupe, "the Eyedropper shows no loupe on the large fixture")
            let w = RenderBudgetWindow(PhotoWindow(model: open))
            defer { w.close() }
            let canvas = try #require(await w.first(CanvasHostView.self))
            let bodies = { () -> Int? in BodyCountSuites.PhotoWindowStrokeTests.editorBodies() }
            try await w.settle(untilStable: bodies)
            let box = canvas.convert(canvas.bounds, to: nil)
            var moves = 0
            let track = try await w.measure("photo eyedropper loupe track, 120 samples", bodies: bodies) {
                try await w.ticks(120) { i in
                    let x = box.minX + box.width * (0.1 + 0.8 * Double(i) / 120)
                    w.send(.mouseMoved, at: CGPoint(x: x, y: box.midY + 40 * sin(Double(i) / 12)))
                    moves += 1
                }
            }
            return (track, moves)
        }
    }
}
#endif
