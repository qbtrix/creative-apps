// PhotoWindowCloseTests.swift: closing a Photo window stops its canvas renders. The window hosts an 8K
// two-layer image on the CPU route, whose first picture takes many seconds in a debug build, and closes
// while that render is in flight; within a few seconds its renderer must be idle (no render running or
// waiting), so a closed window never takes the CPU from the next one (#6136: an 8K window kept rendering
// for over 30 s after it closed and starved PhotoWindowStrokeTests). It reads its own window's renderer,
// never the process-wide count. macOS only.
#if canImport(AppKit)
import AppKit
import PhotoModel
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor @Suite struct PhotoWindowCloseTests {
    @Test(.timeLimit(.minutes(2))) func closingTheWindowStopsItsRenders() async throws {
        let w = RenderBudgetWindow(AnyView(PhotoWindow(model: try BodyCountSuites.PhotoFlipCanvasBudgetTests.document())
            .environment(\.photoRendering, BodyCountSuites.RenderBudgetPhotoLiveTransformTests.rendering(.cpu))))
        // A failed require still closes it (a second close does nothing).
        defer { w.close() }
        var renderer: CanvasRenderer?
        for _ in 0..<400 where renderer?.isIdle != false {
            let canvas = BodyCountSuites.RenderBudgetPhotoLiveTransformTests.canvas(in: w.host)
            renderer = canvas.flatMap(CanvasRenderer.rendering(into:))
            try await Task.sleep(for: .milliseconds(10))
        }
        let open = try #require(renderer, "the window's canvas has no renderer")
        // Plain Bools in the expectations: a failed one reflects its operands, and the renderer holds 8K of tiles.
        let busy = !open.isIdle
        try #require(busy, "the 8K picture finished before the window closed, so the close stopped nothing")

        w.close()
        let clock = ContinuousClock()
        let closed = clock.now
        while !open.isIdle, clock.now - closed < .seconds(3) {
            try await Task.sleep(for: .milliseconds(10))
        }
        let idle = open.isIdle
        print("PHOTO-WINDOW-CLOSE: renderer idle=\(idle) \(clock.now - closed) after the close")
        #expect(idle, "the closed window's renderer still renders \(clock.now - closed) after the close")
    }
}
#endif
