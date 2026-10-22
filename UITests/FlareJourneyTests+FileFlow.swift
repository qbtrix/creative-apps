// FlareJourneyTests+FileFlow.swift: FLJ1 (packet docs/blueprints/flare/features/file-flow.md, Journey steps;
// FL-6 written, FL-7 turned on live). Flare launches on the suite's `weekOfWork` store with Logo.flare open:
// 1. File > Open Recent ▸ lists the week's .flare files and no other app's.
// 2. Title.flare dropped on the stage opens in a new window.
// 3. logo.svg dropped on the stage: the mark reads "Flare can't import SVG yet." and nothing opens.
// 4. File > Open In ▸ Halo: Halo starts with the scene (flare-in-halo, SJ17's path).
// The files are dragged from a small floating window the test runner shows, as a person drags from a folder
// window (the shape of SuiteFileFlowJourneyTests). Every file lives in this test's own temp folder. One shot
// per step, `flare-file-flow-<step>`. It skips until FL-7, when the drop, Open Recent and Open In run on live
// services (FL-3, FL-4, SF-8): FL-7 replaces the skip with `try openRecentDropAndOpenIn()`.
import AppKit
import XCTest

final class FlareFileFlowJourneyTests: XCTestCase {
    /// The drop mark's identifier (SuiteFileControlID.dropMark).
    private static let dropMark = "suite.file.drop-mark"
    /// This file is UITests/<name>, so its grandparent is the repo root.
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    /// The suite's fixture documents (UITests/Fixtures/suite).
    private static let fixtures = root.appending(path: "UITests/Fixtures/suite")
    /// What Open Recent ▸ lists for Flare (the packet's step 1).
    private static let recents = ["Bounce.flare", "Title.flare", "Logo.flare"]
    /// weekOfWork's files of other apps, which Flare's Open Recent never lists.
    private static let others = ["Logo.design", "Cards.design", "Intro.halo", "beach.ora", "Sunset.png"]

    @MainActor func testOpenRecentAndOpenInHalo() throws {
        throw XCTSkip("waits on FL-7")
    }

    @MainActor private func openRecentDropAndOpenIn() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "flare-file-flow-\(UUID().uuidString)")
        let support = folder.appending(path: "Support")
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        for name in ["Logo.flare", "Title.flare"] {
            try FileManager.default.copyItem(at: Self.fixtures.appending(path: name), to: folder.appending(path: name))
        }
        let flare = Journey("Flare", self, arguments: [
            "-SuiteSupportDir", support.path, "-SuiteSkipOnboarding", "YES", "-SuiteFixture", "weekOfWork",
            "-SuiteFixtureDocuments", Self.fixtures.path, "-FlareOpenFile", folder.appending(path: "Logo.flare").path,
        ])
        let window = flare.app.windows.firstMatch
        XCTAssert(window.waitForExistence(timeout: 30), "no window opened")
        let stage = flare.element("flare.stagePane")
        XCTAssert(stage.waitForExistence(timeout: 15), "Logo.flare opened no stage")

        // 1. File > Open Recent ▸: one Open Recent, the week's .flare files, no other app's.
        let file = flare.app.menuBars.firstMatch.menuBarItems["File"]
        file.click()
        XCTAssertEqual(file.menuItems.matching(NSPredicate(format: "title == %@", "Open Recent")).count, 1,
                       "File shows more than one Open Recent")
        let recent = file.menuItems["Open Recent"]
        XCTAssert(recent.waitForExistence(timeout: 5), "File has no Open Recent")
        recent.hover()
        for name in Self.recents {
            XCTAssert(recent.menuItems[name].waitForExistence(timeout: 5), "Open Recent doesn't list \(name)")
        }
        for name in Self.others {
            XCTAssertFalse(recent.menuItems[name].exists, "Flare's Open Recent lists \(name)")
        }
        flare.shot("file-flow-1-open-recent", screen: true)
        flare.press(.escape)
        flare.press(.escape)

        // 2. Title.flare dropped on the stage: it opens in a new window.
        let windows = flare.app.windows.count
        drag(folder.appending(path: "Title.flare"), onto: stage)
        XCTAssert(flare.app.windows["Title"].waitForExistence(timeout: 15), "dropping Title.flare opened no Title window")
        XCTAssertEqual(flare.app.windows.count, windows + 1, "Title.flare didn't open in a window of its own")
        flare.shot("file-flow-2-dropped-flare")

        // 3. logo.svg: the mark says Flare can't import it yet, and nothing opens.
        let svg = folder.appending(path: "logo.svg")
        try Data("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"8\" height=\"8\"/>".utf8).write(to: svg)
        let front = flare.element("flare.stagePane")
        drag(svg, onto: front)
        let mark = flare.app.descendants(matching: .any)[Self.dropMark]
        let refused = NSPredicate(format: "label == %@", "Flare can't import SVG yet.")
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: refused, evaluatedWith: mark)], timeout: 5), .completed,
                       "dropping logo.svg didn't say Flare can't import SVG yet")
        flare.shot("file-flow-3-svg-refused")
        XCTAssertEqual(flare.app.windows.count, windows + 1, "dropping logo.svg opened a window")

        // 4. File > Open In ▸ Halo: Halo starts with the scene.
        file.click()
        let openIn = file.menuItems["Open In"]
        XCTAssert(openIn.waitForExistence(timeout: 5), "File has no Open In")
        XCTAssert(openIn.isEnabled, "Open In is off with Title.flare open and saved")
        openIn.hover()
        let halo = openIn.menuItems["Halo"]
        XCTAssert(halo.waitForExistence(timeout: 5), "Open In doesn't offer Halo for a .flare")
        flare.shot("file-flow-4-open-in", screen: true)
        halo.click()
        addTeardownBlock { @MainActor () async -> Void in
            NSRunningApplication.runningApplications(withBundleIdentifier: "org.creativesuite.halo").forEach { $0.terminate() }
        }
        let started = NSPredicate { _, _ in
            !NSRunningApplication.runningApplications(withBundleIdentifier: "org.creativesuite.halo").isEmpty
        }
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: started, evaluatedWith: nil)], timeout: 30), .completed,
                       "Open In ▸ Halo started no Halo")
        let bundle = try XCTUnwrap(
            NSRunningApplication.runningApplications(withBundleIdentifier: "org.creativesuite.halo").first?.bundleURL)
        XCTAssert(XCUIApplication(url: bundle).windows.firstMatch.waitForExistence(timeout: 30),
                  "Halo made no composition window for the scene")
    }

    /// Shows `file` in a floating window at the screen's top left and drags it onto `target`'s middle.
    @MainActor private func drag(_ file: URL, onto target: XCUIElement) {
        let screen = NSScreen.screens.first?.frame ?? .zero
        let frame = CGRect(x: screen.minX + 40, y: screen.maxY - 200, width: 120, height: 120)
        let panel = NSPanel(contentRect: frame, styleMask: [.nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        panel.contentView = FlareFileDragSource(file: file)
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
private final class FlareFileDragSource: NSView, NSDraggingSource {
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
