// HaloJourneyTests+FileFlow.swift: HFJ1 (packet docs/blueprints/halo/features/file-flow.md, Journey steps;
// HF-6 written and skipped, HF-7 turns it on live). Halo launches on the suite's `weekOfWork` store with
// Intro.halo open:
// 1. File > Open Recent ▸ lists Intro.halo and no other app's documents.
// 2. Promo.halo dropped on the viewer opens in a new window.
// 3. Sunset.png dropped on the viewer: the mark says what Halo's drop rule makes of it (Halo places no
//    images until S20) and no Halo window opens.
// 4. Bounce.flare dropped on the viewer: a composition with the scene, as Open In ▸ Halo makes, in this
//    window.
// The files are dragged from a small floating window the test runner shows, as a person drags from a
// folder window (`dragFile`, Journey+FileDrag.swift). Every file lives in this test's own temp folder;
// Promo.halo is a copy of the suite's Intro.halo. One shot per step, `halo-file-flow-<step>`.
import AppKit
import XCTest

final class HaloFileFlowJourneyTests: XCTestCase {
    /// The drop mark's identifier (SuiteFileControlID.dropMark).
    private static let dropMark = "suite.file.drop-mark"
    /// This file is UITests/<name>, so its grandparent is the repo root.
    private static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    /// The suite's fixture documents (UITests/Fixtures/suite).
    private static let fixtures = root.appending(path: "UITests/Fixtures/suite")
    /// weekOfWork's files of other apps, which Halo's Open Recent never lists.
    private static let others = ["Logo.design", "Cards.design", "Bounce.flare", "Title.flare", "beach.ora", "Sunset.png"]

    /// HFJ1: Open Recent lists Halo's files; a .halo drop opens, a PNG is refused, a .flare comes in as a scene.
    @MainActor func testOpenRecentAndDrop() throws {
        throw XCTSkip("waits on HF-7")
        let folder = FileManager.default.temporaryDirectory.appending(path: "halo-file-flow-\(UUID().uuidString)")
        let support = folder.appending(path: "Support")
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let intro = Self.fixtures.appending(path: "Intro.halo")
        try FileManager.default.copyItem(at: intro, to: folder.appending(path: "Intro.halo"))
        try FileManager.default.copyItem(at: intro, to: folder.appending(path: "Promo.halo"))
        for name in ["Sunset.png", "Bounce.flare"] {
            try FileManager.default.copyItem(at: Self.fixtures.appending(path: name), to: folder.appending(path: name))
        }
        let halo = Journey("Halo", self, arguments: [
            "-SuiteSupportDir", support.path, "-SuiteSkipOnboarding", "YES", "-SuiteFixture", "weekOfWork",
            "-SuiteFixtureDocuments", Self.fixtures.path, "-HaloOpenFile", folder.appending(path: "Intro.halo").path,
        ])
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let viewer = halo.element("halo.viewer")
        XCTAssert(viewer.waitForExistence(timeout: 15), "Intro.halo opened no viewer")

        // 1. File > Open Recent ▸: one Open Recent, Intro.halo, no other app's documents.
        let file = halo.app.menuBars.firstMatch.menuBarItems["File"]
        file.click()
        XCTAssertEqual(file.menuItems.matching(NSPredicate(format: "title == %@", "Open Recent")).count, 1,
                       "File shows more than one Open Recent")
        let recent = file.menuItems["Open Recent"]
        XCTAssert(recent.waitForExistence(timeout: 5), "File has no Open Recent")
        recent.hover()
        XCTAssert(recent.menuItems["Intro.halo"].waitForExistence(timeout: 5), "Open Recent doesn't list Intro.halo")
        for name in Self.others {
            XCTAssertFalse(recent.menuItems[name].exists, "Halo's Open Recent lists \(name)")
        }
        halo.shot("file-flow-1-open-recent", screen: true)
        halo.press(.escape)
        halo.press(.escape)

        // 2. Promo.halo dropped on the viewer: it opens in a new window.
        let windows = halo.app.windows.count
        dragFile(folder.appending(path: "Promo.halo"), onto: viewer)
        XCTAssert(halo.app.windows["Promo"].waitForExistence(timeout: 15), "dropping Promo.halo opened no Promo window")
        XCTAssertEqual(halo.app.windows.count, windows + 1, "Promo.halo didn't open in a window of its own")
        halo.shot("file-flow-2-dropped-halo")

        // 3. Sunset.png: Halo places no images yet, so the mark says where it goes, and no Halo window opens.
        let front = halo.element("halo.viewer")
        dragFile(folder.appending(path: "Sunset.png"), onto: front)
        let mark = halo.app.descendants(matching: .any)[Self.dropMark]
        XCTAssert(mark.waitForExistence(timeout: 5), "dropping Sunset.png showed no mark")
        halo.shot("file-flow-3-png")
        XCTAssertEqual(halo.app.windows.count, windows + 1, "dropping Sunset.png opened a Halo window")

        // 4. Bounce.flare: a composition with the scene in the front window, as Open In ▸ Halo makes.
        dragFile(folder.appending(path: "Bounce.flare"), onto: front)
        XCTAssert(halo.app.descendants(matching: .any)["Bounce"].waitForExistence(timeout: 15),
                  "dropping Bounce.flare made no Bounce composition")
        XCTAssertEqual(halo.app.windows.count, windows + 1, "Bounce.flare opened a window instead of a composition")
        halo.shot("file-flow-4-flare-scene")
    }
}
