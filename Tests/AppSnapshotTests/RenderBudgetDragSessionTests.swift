// RenderBudgetDragSessionTests.swift: the render-budget harness leaves no
// system drag session behind (#2971). A harness drag over a `.draggable` view
// begins an AppKit drag session that starts on the next run-loop turn and then
// blocks the main thread waiting for a mouse-up only the window server sends,
// which a test process never gets. Left open, it froze whichever later test
// turned the run loop first (a snapshot's `render`), at 0% CPU and past every
// `.timeLimit`. `RenderBudgetWindow.close()` ends it (DragSessions in
// RenderBudgetHarness.swift). This test drags a draggable, closes the window
// and turns the run loop: a leaked session blocks that turn until a watchdog
// posts the mouse-up five seconds later, so the leak fails here by name
// instead of hanging the pass. macOS only.
#if canImport(AppKit)
import AppKit
import SwiftUI
import Testing

@MainActor @Suite struct RenderBudgetDragSessionTests {
    @Test(.timeLimit(.minutes(1))) func closingTheWindowEndsTheDragSession() async throws {
        let w = RenderBudgetWindow(
            Text("Drag me").frame(width: 200, height: 80).draggable("payload")
                .accessibilityIdentifier("drag.source"))
        let source = try #require(await w.element("drag.source"), "no draggable")
        let start = CGPoint(x: source.midX, y: source.midY)
        try await w.drag(from: start, by: CGVector(dx: 300, dy: -200), samples: 20)
        w.close()

        // A leaked session waits for a mouse-up; the rescue posts one to this process five seconds on.
        let rescue = Self.mouseUp(in: 5, to: NSApplication.shared)
        let took = Self.turnTheRunLoop()
        rescue.cancel()
        #expect(took < .seconds(4), "a drag session outlived its window and held the run loop for \(took)")
    }

    /// A mouse-up put in `app`'s event queue `seconds` from now, off the blocked main thread (postEvent is
    /// thread-safe; Swift marks it main actor, so it is called through its IMP), unless cancelled first.
    nonisolated static func mouseUp(in seconds: Double, to app: NSApplication) -> DispatchWorkItem {
        nonisolated(unsafe) let app: NSObject = app
        let post = DispatchWorkItem {
            let up = NSEvent.mouseEvent(
                with: .leftMouseUp, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
                eventNumber: 0, clickCount: 1, pressure: 0)
            typealias PostEvent = @convention(c) (NSObject, Selector, NSEvent, Bool) -> Void
            let post = NSSelectorFromString("postEvent:atStart:")
            up.map { unsafeBitCast(app.method(for: post), to: PostEvent.self)(app, post, $0, true) }
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + seconds, execute: post)
        return post
    }

    /// A 0.3 s turn of the main run loop, as a snapshot's `render` takes; how long it really took.
    static func turnTheRunLoop() -> Duration {
        ContinuousClock().measure { RunLoop.main.run(until: Date().addingTimeInterval(0.3)) }
    }
}
#endif
