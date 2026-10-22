// Journey+FileDrag.swift: a file dragged from the test runner onto an app, as a person drags one from a folder
// window. Every <X>JourneyTests target compiles it (project.yml), so each app's file-flow journey drops files
// the same way (photo file-flow PF-7; the launcher's SuiteFileFlowJourneyTests keeps its own copy).
import AppKit
import XCTest

extension XCTestCase {
    /// Shows `file` in a small floating window at the screen's top left and drags it onto `target`'s middle.
    /// The file must exist; the drop carries its URL, as a drag from a folder window does.
    @MainActor func dragFile(_ file: URL, onto target: XCUIElement) {
        let screen = NSScreen.screens.first?.frame ?? .zero
        let frame = CGRect(x: screen.minX + 40, y: screen.maxY - 200, width: 120, height: 120)
        let panel = NSPanel(contentRect: frame, styleMask: [.nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.contentView = JourneyFileDragSource(file: file)
        panel.orderFrontRegardless()
        defer { panel.close() }
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
        // XCUI coordinates are screen points from the top left; AppKit's from the bottom left.
        let origin = target.frame.origin
        let from = target.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: frame.midX - origin.x, dy: screen.maxY - frame.midY - origin.y))
        from.press(forDuration: 0.3, thenDragTo: target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    }
}

/// A view that starts a file drag of `file` when the pointer drags on it.
final class JourneyFileDragSource: NSView, NSDraggingSource {
    private let file: URL

    init(file: URL) {
        self.file = file
        super.init(frame: .zero)
    }

    required init?(coder: NSCoder) { nil }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDragged(with event: NSEvent) {
        let item = NSDraggingItem(pasteboardWriter: file as NSURL)
        item.setDraggingFrame(bounds, contents: NSWorkspace.shared.icon(forFile: file.path))
        beginDraggingSession(with: [item], event: event, source: self)
    }

    func draggingSession(_ session: NSDraggingSession,
                         sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation { .copy }
}
