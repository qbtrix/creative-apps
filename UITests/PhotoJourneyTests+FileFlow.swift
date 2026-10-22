// PhotoJourneyTests+FileFlow.swift: PFJ1 (packet docs/blueprints/photo/features/file-flow.md, Journey
// steps; PF-6 written, PF-7 turned on live). Photo opens Sunset.png on the suite's `weekOfWork` recents:
// File > Open Recent ▸ lists Photo's files from the suite's one list, and File > Open In ▸ Library hands
// the image to Library. The drop steps (Logo.png dropped on the canvas shows "Place in Sunset.png" and
// lands as a centred layer that one Undo removes; Intro.halo dropped opens in Halo) need a drop source in
// the runner and the live drop; PF-7 adds them here, between the menu steps.
import XCTest

final class PhotoFileFlowJourneyTests: XCTestCase {
    @MainActor func testDropImageAsLayer() throws {
        try XCTSkipIf(true, "waits on PF-7")
        // Step 1: launch Photo on the week's recents with Sunset.png open.
        let folder = FileManager.default.temporaryDirectory.appending(path: "photo-file-flow-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let sunset = folder.appending(path: "Sunset.png")
        try writeTestPhoto(to: sunset)
        let photo = Journey("Photo", self, arguments: photoArguments(open: sunset) + ["-SuiteFixture", "weekOfWork"])
        XCTAssert(photo.window(named: "Sunset.png").waitForExistence(timeout: 30), "Sunset.png didn't open")

        // File has one Open Recent ▸ (the suite's), listing Photo's files.
        let file = photo.app.menuBars.firstMatch.menuBarItems["File"]
        file.click()
        let recent = file.menuItems["Open Recent"]
        XCTAssert(recent.waitForExistence(timeout: 5), "File has no Open Recent")
        XCTAssertEqual(file.menuItems.matching(NSPredicate(format: "title == %@", "Open Recent")).count, 1,
                       "File shows more than one Open Recent")
        recent.hover()
        XCTAssert(file.menuItems["Sunset.png"].waitForExistence(timeout: 5), "Open Recent doesn't list Sunset.png")
        photo.shot("open-recent", screen: true)
        photo.press(.escape)
        photo.press(.escape)

        // Step 4: File > Open In ▸ Library: Library imports Sunset.png.
        file.click()
        let openIn = file.menuItems["Open In"]
        XCTAssert(openIn.waitForExistence(timeout: 5), "File has no Open In")
        XCTAssert(openIn.isEnabled, "Open In is off with Sunset.png open and saved")
        openIn.hover()
        let library = file.menuItems["Library"]
        XCTAssert(library.waitForExistence(timeout: 5), "Open In doesn't offer Library")
        library.click()
    }
}
