// RenderBudgetDragSessionTests.swift: the snapshot tests leave no system drag
// session behind (#2971). A harness drag over a `.draggable` view begins an
// AppKit drag session that starts on the next run-loop turn and then blocks
// the main thread waiting for a mouse-up only the window server sends, which
// a test process never gets. Left open, it froze whichever later test turned
// the run loop first (a snapshot's `render`), at 0% CPU and past every
// `.timeLimit`. DragSessions (RenderBudgetHarness.swift) hands such a drag an
// idle session, and since macOS 27's `.draggable` skips that swap, it also
// makes the drag manager's wait return at once. The first test drags a
// draggable; the second begins two real sessions through AppKit's own method.
// Each closes its window and turns the run loop: a blocking session holds that
// turn until a watchdog posts the mouse-up five seconds later, so the leak
// fails here by name instead of hanging the pass. Ending a real one that way
// leaves the main run loop to return, which ends the process at the closing
// sleep, unfinished. macOS only.
#if canImport(AppKit)
import AppKit
import SwiftUI
import Testing

@MainActor @Suite struct RenderBudgetDragSessionTests {
    @Test(.timeLimit(.minutes(1))) func aDragOverADraggableLeavesNoSession() async throws {
        let w = RenderBudgetWindow(
            Text("Drag me").frame(width: 200, height: 80).draggable("payload")
                .accessibilityIdentifier("drag.source"))
        let source = try #require(await w.element("drag.source"), "no draggable")
        let start = CGPoint(x: source.midX, y: source.midY)
        let begun = DragSessions.begun
        try await w.drag(from: start, by: CGVector(dx: 300, dy: -200), samples: 20)
        w.close()
        #expect(DragSessions.begun > begun, "the drag never asked for a drag session, so this proves nothing")

        // A leaked session waits for a mouse-up; the rescue posts one to this process five seconds on.
        // not-timing: a hang guard, not a budget. A clean run returns at once; only a leak waits for the rescue.
        let rescue = Self.postMouseUp(after: 5, to: NSApplication.shared)
        let took = Self.turnTheRunLoop()
        rescue.cancel()
        #expect(took < .seconds(4), "a drag session outlived its window and held the run loop for \(took)")
        // Nor may the main run loop return: the test process would exit 0 here, unfinished.
        try await Task.sleep(for: .milliseconds(100))
    }

    /// A drag can begin a real session by a path that skips the NSView swap (macOS 27's `.draggable` does), so a
    /// real session must not hold the run loop either. Two in a row, begun through AppKit's own method, so a
    /// skipped wait can't leave the next drag stuck.
    @Test(.timeLimit(.minutes(1))) func aRealSessionNeverHoldsTheRunLoop() async throws {
        _ = DragSessions.faked
        let held = DragSessions.held
        for round in 1...2 {
            let window = NSWindow(
                contentRect: CGRect(x: 0, y: 0, width: 200, height: 200), styleMask: [.borderless], backing: .buffered,
                defer: false)
            window.isReleasedWhenClosed = false
            let view = NSView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
            window.contentView = view
            window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
            window.orderFrontRegardless()
            let event = try #require(NSEvent.mouseEvent(
                with: .leftMouseDragged, location: NSPoint(x: 100, y: 100), modifierFlags: [],
                timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
                eventNumber: 0, clickCount: 1, pressure: 1))
            let item = NSDraggingItem(pasteboardWriter: "payload" as NSString)
            item.setDraggingFrame(CGRect(x: 90, y: 90, width: 20, height: 20), contents: nil)
            _ = DragSessions.beginRealSession(on: view, items: [item], event: event, source: CopySource())
            window.close()

            let rescue = Self.postMouseUp(after: 5, to: NSApplication.shared)
            let took = Self.turnTheRunLoop()
            rescue.cancel()
            #expect(took < .seconds(4), "real session \(round) held the run loop for \(took)")
        }
        // The first reaches the drag manager's wait; AppKit may refuse the second outright, which holds nothing.
        #expect(DragSessions.held > held, "no real session reached the drag manager, so this proves nothing")
        try await Task.sleep(for: .milliseconds(100))
    }

    final class CopySource: NSObject, NSDraggingSource {
        func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext)
            -> NSDragOperation { .copy }
    }

    /// A mouse-up put in `app`'s event queue `delay` seconds from now from a background thread (the main one is
    /// the one blocked), unless cancelled first. postEvent is thread-safe; Swift marks it main actor, so it is
    /// called through its IMP.
    nonisolated static func postMouseUp(after delay: Double, to app: NSApplication) -> DispatchWorkItem {
        nonisolated(unsafe) let app: NSObject = app
        let post = DispatchWorkItem {
            typealias PostEvent = @convention(c) (NSObject, Selector, NSEvent, Bool) -> Void
            let selector = NSSelectorFromString("postEvent:atStart:")
            guard let up = NSEvent.mouseEvent(
                with: .leftMouseUp, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
                eventNumber: 0, clickCount: 1, pressure: 0)
            else { return }
            unsafeBitCast(app.method(for: selector), to: PostEvent.self)(app, selector, up, true)
        }
        DispatchQueue.global().asyncAfter(deadline: .now() + delay, execute: post)
        return post
    }

    /// A 0.3 s turn of the main run loop, as a snapshot's `render` takes; how long it really took.
    static func turnTheRunLoop() -> Duration {
        ContinuousClock().measure { RunLoop.main.run(until: Date().addingTimeInterval(0.3)) }
    }
}
#endif
