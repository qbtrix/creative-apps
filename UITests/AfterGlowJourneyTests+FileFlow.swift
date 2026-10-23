// AfterGlowJourneyTests+FileFlow.swift: SJ-F1 (packet suite/features/file-flow.md, Journey steps 1 to 3;
// SF-2 written, SF-4 turned on). On `weekOfWork`, File > Open Recent ▸ on the home lists the week's files
// newest first; Intro.halo dragged onto the home shows "Open in Halo"; notes.xyz is refused in words and
// opens nothing. The files are dragged from a small floating window the test runner shows, as a person drags
// from a folder window. It lives in the launcher's bundle, which has SuiteHarness, so its shots go under
// `afterglow` and are audited.
import AppKit
import XCTest

final class SuiteFileFlowJourneyTests: XCTestCase {
    /// The drop mark's identifier (SuiteFileControlID.dropMark).
    private static let dropMark = "suite.file.drop-mark"

    @MainActor func testDropOnHomeAndOpenRecent() throws {
        let suite = SuiteHarness(self)
        let home = suite.launch(fixture: "weekOfWork", arguments: ["-SuitePerfProbe", "YES"])
        let window = home.app.windows.firstMatch
        XCTAssert(window.waitForExistence(timeout: 30), "AfterGlow opened no window")

        // 1. File > Open Recent ▸ lists the week's files, newest first.
        home.app.menuBars.menuBarItems["File"].click()
        let recent = home.app.menuBars.menuItems["Open Recent"]
        XCTAssert(recent.waitForExistence(timeout: 5), "File has no Open Recent")
        recent.hover()
        for name in AfterGlowJourneyTests.weekOfWork {
            XCTAssert(home.app.menuBars.menuItems[name].waitForExistence(timeout: 5), "Open Recent doesn't list \(name)")
        }
        home.shot("file-flow-open-recent", screen: true)
        home.press(.escape)
        home.press(.escape)

        // 2. Intro.halo dropped on the home: the mark says it opens in Halo.
        let files = suite.support.appending(path: "drop")
        try FileManager.default.createDirectory(at: files, withIntermediateDirectories: true)
        let mark = home.app.descendants(matching: .any)[Self.dropMark]
        let windows = home.app.windows.count
        drag(files.appending(path: "Intro.halo"), onto: window)
        XCTAssert(mark.waitForExistence(timeout: 5), "dropping Intro.halo showed no mark")
        XCTAssertEqual(mark.label, "Open in Halo")
        home.shot("file-flow-drop-mark-open")

        // 3. notes.xyz: the mark says why it can't open, and the drop does nothing.
        drag(files.appending(path: "notes.xyz"), onto: window)
        let refused = NSPredicate(format: "label == %@", "AfterGlow can't open .xyz files.")
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: refused, evaluatedWith: mark)], timeout: 5), .completed,
                       "dropping notes.xyz didn't say it can't open .xyz files")
        home.shot("file-flow-drop-mark-refuse")
        XCTAssertEqual(home.app.windows.count, windows, "dropping notes.xyz opened a window")
    }

    /// Writes `file`, shows it in a floating window at the screen's top left and drags it onto `target`'s middle.
    @MainActor private func drag(_ file: URL, onto target: XCUIElement) {
        FileManager.default.createFile(atPath: file.path, contents: Data())
        let screen = NSScreen.screens.first?.frame ?? .zero
        let frame = CGRect(x: screen.minX + 40, y: screen.maxY - 200, width: 120, height: 120)
        let panel = NSPanel(contentRect: frame, styleMask: [.nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.contentView = FileDragSource(file: file)
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
private final class FileDragSource: NSView, NSDraggingSource {
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
