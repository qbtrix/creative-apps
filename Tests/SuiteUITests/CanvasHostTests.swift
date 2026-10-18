// CanvasHostTests.swift: the canvas host on the `canvas-host` page in a real
// window (canvas-host CH-3): drags, the overlay, hit testing, its id. macOS only.
import AppKit
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite(.serialized) struct CanvasHostTests {
    @Test func dragOf120SamplesCallsTheDelegateAndRunsAtMostOneBody() throws {
        let log = CanvasHostLog()
        let window = host(CanvasHostPage(log: log))
        defer { window.close() }
        let canvas = try #require(canvasView(in: window.contentView))
        let board = canvas.artboard
        #if DEBUG
        let bodiesBefore = CanvasHostPage.bodyRuns
        #endif
        canvas.press(at: CGPoint(x: board.minX + 10, y: board.midY))
        for step in 1...120 {
            canvas.move(to: CGPoint(x: board.minX + 10 + CGFloat(step) * 2, y: board.midY))
        }
        settle()
        #expect(pathPoints(canvas.overlay.path) == 120)
        #expect(log.drags == 120 && log.endDrags == 0)
        canvas.release()
        settle()
        #expect(log.drags == 120 && log.endDrags == 1)
        #if DEBUG  // the body counter exists only in debug builds
        #expect(CanvasHostPage.bodyRuns - bodiesBefore <= 1, "a drag ran \(CanvasHostPage.bodyRuns - bodiesBefore) bodies")
        #endif
        #expect(canvas.live.isEmpty)
        #expect(pathPoints(canvas.overlay.path) == 0)
        #expect(log.lines.last == "endDrag after 120 samples")
    }
    @Test func clickWithNoMoveStillEndsTheDrag() throws {
        let log = CanvasHostLog()
        let window = host(CanvasHostPage(log: log))
        defer { window.close() }
        let canvas = try #require(canvasView(in: window.contentView))
        canvas.press(at: CGPoint(x: canvas.artboard.midX, y: canvas.artboard.midY))
        canvas.release()
        canvas.release()
        #expect(log.drags == 0 && log.endDrags == 1)
    }
    @Test func onlyTheArtboardTakesAClickAndTheHostIsTheCanvas() throws {
        let window = host(CanvasHostPage())
        defer { window.close() }
        let canvas = try #require(canvasView(in: window.contentView))
        let superview = try #require(canvas.superview)
        let board = canvas.artboard
        let topLeft = canvas.documentPoint(CGPoint(x: board.minX, y: board.maxY))
        #expect(abs(topLeft.x) < 0.5 && abs(topLeft.y) < 0.5)
        #expect(canvas.hitTest(canvas.convert(CGPoint(x: board.midX, y: board.midY), to: superview)) === canvas)
        #expect(canvas.hitTest(canvas.convert(CGPoint(x: 1, y: 1), to: superview)) == nil)
        #expect(canvas.accessibilityIdentifier() == "suite.canvas")
        #expect(canvas.overlay.name == RenderingControlID.overlay)
    }
}

/// The page in a 960 x 600 window on screen, laid out.
@MainActor private func host(_ page: CanvasHostPage) -> NSWindow {
    let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 960, height: 600), styleMask: [.titled],
                          backing: .buffered, defer: false)
    window.isReleasedWhenClosed = false
    window.contentView = NSHostingView(rootView: page.frame(width: 960, height: 600))
    window.orderFrontRegardless()
    settle()
    return window
}
@MainActor private func settle() { RunLoop.main.run(until: Date().addingTimeInterval(0.2)) }
@MainActor private func canvasView(in view: NSView?) -> CanvasHostView? {
    guard let view else { return nil }
    return view as? CanvasHostView ?? view.subviews.lazy.compactMap { canvasView(in: $0) }.first
}
/// How many points a path moves or lines to; 0 for no path.
private func pathPoints(_ path: CGPath?) -> Int {
    var count = 0
    path?.applyWithBlock { if [CGPathElementType.moveToPoint, .addLineToPoint].contains($0.pointee.type) { count += 1 } }
    return count
}
