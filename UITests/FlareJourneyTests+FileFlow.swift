// FlareJourneyTests+FileFlow.swift: FLJ1 (packet docs/blueprints/flare/features/file-flow.md, Journey steps;
// FL-6 written, FL-7 turned on live). Flare launches on the suite's `weekOfWork` store with Logo.flare open:
// 1. File > Open Recent ▸ lists the week's .flare files and no other app's.
// 2. Title.flare dropped on the stage opens in a new window.
// 3. logo.svg dropped on the stage: its group becomes a layer, the status reads "Placed logo.svg: 1 layer." and
//    nothing opens.
// 4. File > Open In ▸ offers no Halo yet: a .flare's only reader is Flare (SuiteTypeRegistry.standard) until
//    flare-in-halo FH-1 adds Halo, which then starts with the scene (SJ17's path). Until then the step checks
//    the submenu lists no Halo and the test ends in a skip naming FH-1, so steps 1-3 still count.
// The files are dragged from a small floating window the test runner shows, as a person drags from a folder
// window (`dragFile`, Journey+FileDrag.swift). Every file lives in this test's own temp folder. One shot per
// step, `flare-file-flow-<step>`. FL-7 turned it on once the drop, Open Recent and Open In ran on live
// services (FL-3, FL-4, SF-8).
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
        try openRecentDropAndOpenIn()
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
        dragFile(folder.appending(path: "Title.flare"), onto: stage)
        XCTAssert(flare.app.windows["Title"].waitForExistence(timeout: 15), "dropping Title.flare opened no Title window")
        XCTAssertEqual(flare.app.windows.count, windows + 1, "Title.flare didn't open in a window of its own")
        flare.shot("file-flow-2-dropped-flare")

        // 3. logo.svg: its group is placed as a layer (svg-place), and nothing opens.
        let svg = folder.appending(path: "logo.svg")
        try Data(("<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"80\" height=\"80\">"
            + "<g id=\"logo\"><rect width=\"80\" height=\"80\" fill=\"#E53935\"/></g></svg>").utf8).write(to: svg)
        let front = flare.element("flare.stagePane")
        dragFile(svg, onto: front)
        let note = flare.element("flare.status.place")
        let placed = NSPredicate(format: "label == %@ OR value == %@", "Placed logo.svg: 1 layer.", "Placed logo.svg: 1 layer.")
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: placed, evaluatedWith: note)], timeout: 5), .completed,
                       "dropping logo.svg didn't place its group")
        flare.shot("file-flow-3-svg-placed")
        XCTAssertEqual(flare.app.windows.count, windows + 1, "dropping logo.svg opened a window")

        // 4. File > Open In ▸: no Halo until flare-in-halo FH-1 (Halo refuses .importAnimation till then).
        file.click()
        let openIn = file.menuItems["Open In"]
        XCTAssert(openIn.waitForExistence(timeout: 5), "File has no Open In")
        openIn.hover()
        XCTAssertFalse(openIn.menuItems["Halo"].waitForExistence(timeout: 2),
                       "Open In offers Halo for a .flare: flare-in-halo FH-1 landed, so turn the Halo half of step 4 on")
        flare.shot("file-flow-4-open-in", screen: true)
        flare.press(.escape)
        flare.press(.escape)
        throw XCTSkip("step 4's Open In ▸ Halo waits on flare-in-halo FH-1: no other app reads a .flare yet")
    }
}
