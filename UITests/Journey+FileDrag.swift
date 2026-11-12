// Journey+FileDrag.swift: a file dragged from the test runner onto an app, as a person drags one from a folder
// window. Every <X>JourneyTests target compiles it (project.yml), so each app's file-flow journey, the launcher's
// SuiteFileFlowJourneyTests included, drops files the same way (photo file-flow PF-7).
//
// The runner shows the file in a small panel and XCUI presses on it and drags to the target. A test method runs
// inside one run-loop callout, so nothing calls NSApp.nextEvent/sendEvent while it runs: spinning the run loop (XCUI's
// own waits included) queues the window server's mouse events but never hands them to the panel. JourneyEventPump
// does that dispatch on a timer for the length of the drag, so the panel sees mouseDown/mouseDragged and starts a
// real drag session. Lines prefixed `FILEDRAG:` in the test log trace each step (frames, pump ticks, source
// callbacks, the session's end and its operation).
import AppKit
import XCTest

extension XCTestCase {
    /// Shows `file` in a small floating window at the screen's top left and drags it onto `target`'s middle.
    /// The file must exist; the drop carries its URL, as a drag from a folder window does.
    @MainActor func dragFile(_ file: URL, onto target: XCUIElement) {
        let screen = NSScreen.screens.first?.frame ?? .zero
        let frame = CGRect(x: screen.minX + 40, y: screen.maxY - 200, width: 120, height: 120)
        let source = JourneyFileDragSource(file: file)
        let panel = NSPanel(contentRect: frame, styleMask: [.nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.contentView = source
        panel.orderFrontRegardless()
        let pump = JourneyEventPump(panel: panel)
        defer {
            pump.stop()
            panel.close()
        }
        pump.wait(0.3) { false }
        // XCUI coordinates are screen points from the top left; AppKit's from the bottom left.
        let targetFrame = target.frame
        let press = CGPoint(x: frame.midX, y: screen.maxY - frame.midY)
        let drop = CGPoint(x: targetFrame.midX, y: targetFrame.midY)
        let screens = NSScreen.screens.map { "\($0.frame)" }.joined(separator: " ")
        print("FILEDRAG: start \(file.lastPathComponent) screens=\(screens) panel=\(frame) visible=\(panel.isVisible)"
              + " window=\(panel.windowNumber) target=\(targetFrame) press=\(press) drop=\(drop)"
              + " under-press=\(JourneyEventPump.windowOwner(at: NSPoint(x: frame.midX, y: frame.midY)))")
        let from = target.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: press.x - targetFrame.minX, dy: press.y - targetFrame.minY))
        from.press(forDuration: 0.3, thenDragTo: target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
        print("FILEDRAG: xcui drag returned ticks=\(pump.ticks) dispatched=\(pump.dispatched)"
              + " down=\(source.sawMouseDown) began=\(source.began) ended=\(source.ended.map { "\($0.rawValue)" } ?? "no")")
        // The session can still be running; its end (and the drop's data request) arrives through the pump.
        pump.wait(source.began ? 3 : 0.3) { source.ended != nil }
        print("FILEDRAG: done \(file.lastPathComponent) ticks=\(pump.ticks) dispatched=\(pump.dispatched)"
              + " down=\(source.sawMouseDown) began=\(source.began) ended=\(source.ended.map { "\($0.rawValue)" } ?? "no")")
    }
}

/// Hands the runner's queued events to its windows on a timer, as NSApp.run would, while a test method runs.
@MainActor final class JourneyEventPump {
    private(set) var ticks = 0
    private(set) var dispatched = 0
    private var timer: Timer?
    private var busy = false
    private var lastState = ""
    private let panel: NSWindow

    init(panel: NSWindow) {
        self.panel = panel
        let timer = Timer(timeInterval: 0.005, repeats: true) { _ in MainActor.assumeIsolated { self.tick() } }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Spins the main run loop (so the pump runs) for up to `seconds`, or until `done`.
    func wait(_ seconds: TimeInterval, until done: () -> Bool) {
        let end = Date().addingTimeInterval(seconds)
        while Date() < end, !done() { RunLoop.main.run(until: Date().addingTimeInterval(0.01)) }
    }

    private func tick() {
        ticks += 1
        let mode = RunLoop.current.currentMode
        let location = NSEvent.mouseLocation
        let under = Self.windowOwner(at: location)
        let state = "mode=\(mode?.rawValue ?? "none") buttons=\(NSEvent.pressedMouseButtons) under=\(under)"
        if state != lastState || ticks == 1 {
            print("FILEDRAG: tick \(ticks) \(state) mouse=\(location) panel=\(panel.windowNumber)")
            lastState = state
        }
        // Only at the top level, as NSApp.run: a nested tracking loop (the drag's own) pulls its events itself.
        guard !busy, mode == .default else { return }
        busy = true
        defer { busy = false }
        while let event = NSApp.nextEvent(matching: .any, until: .distantPast, inMode: .default, dequeue: true) {
            dispatched += 1
            if [.leftMouseDown, .leftMouseUp].contains(event.type) {
                print("FILEDRAG: dispatch \(event.type.rawValue) window=\(event.windowNumber) at=\(event.locationInWindow)")
            }
            NSApp.sendEvent(event)
        }
    }

    /// The topmost window at an AppKit screen point, as "number:owner".
    static func windowOwner(at point: NSPoint) -> String {
        let number = NSWindow.windowNumber(at: point, belowWindowWithWindowNumber: 0)
        let info = CGWindowListCopyWindowInfo([.optionIncludingWindow], CGWindowID(number)) as? [[String: Any]]
        let owner = info?.first?[kCGWindowOwnerName as String] as? String ?? "?"
        return "\(number):\(owner)"
    }
}

/// A view that starts a file drag of `file` when the pointer drags on it.
final class JourneyFileDragSource: NSView, NSDraggingSource {
    private let file: URL
    private(set) var sawMouseDown = false
    private(set) var began = false
    private(set) var ended: NSDragOperation?

    init(file: URL) {
        self.file = file
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        sawMouseDown = true
        print("FILEDRAG: source mouseDown at=\(event.locationInWindow)")
    }

    override func mouseDragged(with event: NSEvent) {
        guard !began else { return }
        began = true
        print("FILEDRAG: source mouseDragged, beginDraggingSession at=\(event.locationInWindow)")
        let item = NSDraggingItem(pasteboardWriter: file as NSURL)
        item.setDraggingFrame(bounds, contents: NSWorkspace.shared.icon(forFile: file.path))
        let session = beginDraggingSession(with: [item], event: event, source: self)
        print("FILEDRAG: beginDraggingSession returned pasteboard=\(session.draggingPasteboard.types?.map(\.rawValue) ?? [])")
    }

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }

    func draggingSession(_ session: NSDraggingSession, willBeginAt screenPoint: NSPoint) {
        print("FILEDRAG: session willBeginAt=\(screenPoint)")
    }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        ended = operation
        print("FILEDRAG: session endedAt=\(screenPoint) operation=\(operation.rawValue)")
    }
}
