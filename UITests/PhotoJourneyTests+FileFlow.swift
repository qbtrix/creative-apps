// PhotoJourneyTests+FileFlow.swift: PFJ1 (packet docs/blueprints/photo/features/file-flow.md, Journey
// steps; PF-6 written, PF-7 turned on live). Photo opens Sunset.png on the suite's `weekOfWork` recents:
// File > Open Recent ▸ lists Photo's files from the suite's one list; Logo.png dropped on the canvas shows
// "Place in Sunset" and lands as a layer "Logo" that one Undo removes; Intro.halo dropped opens in Halo;
// File > Open In ▸ Library hands the image to Library. The files are dragged from a small window the test
// runner shows (Journey+FileDrag.swift).
import XCTest

final class PhotoFileFlowJourneyTests: XCTestCase {
    /// The drop mark's identifier (SuiteFileControlID.dropMark).
    private static let dropMark = "suite.file.drop-mark"

    @MainActor func testDropImageAsLayer() throws {
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

        // Step 2: Logo.png dropped on the canvas: the mark says it places, a layer "Logo" lands in one
        // Place step, and one Undo takes it away.
        let canvas = photo.element("suite.canvas")
        XCTAssert(canvas.waitForExistence(timeout: 5), "Photo shows no canvas (suite.canvas)")
        let mark = photo.app.descendants(matching: .any)[Self.dropMark]
        let logo = photo.app.staticTexts["Logo"]
        XCTAssertFalse(logo.exists, "Sunset.png already has a layer Logo")
        let logoFile = folder.appending(path: "Logo.png")
        try writeTestPhoto(to: logoFile, width: 200, height: 150)
        dragFile(logoFile, onto: canvas)
        XCTAssert(mark.waitForExistence(timeout: 5), "dropping Logo.png showed no mark")
        XCTAssert(mark.label.hasPrefix("Place in Sunset"), "the mark reads \(mark.label), not Place in Sunset")
        XCTAssert(logo.waitForExistence(timeout: 10), "dropping Logo.png listed no layer Logo")
        let undo = photo.app.buttons["Undo Place"]
        XCTAssert(undo.waitForExistence(timeout: 5), "the drop made no Place step")
        photo.shot("drop-placed")
        undo.click()
        XCTAssert(logo.waitForNonExistence(timeout: 5), "one Undo didn't take the layer Logo away")
        photo.shot("drop-undone")

        // Step 3: Intro.halo dropped on the canvas: the mark says Halo, and Halo opens it.
        let intro = folder.appending(path: "Intro.halo")
        FileManager.default.createFile(atPath: intro.path, contents: Data())
        dragFile(intro, onto: canvas)
        let toHalo = NSPredicate(format: "label == %@", "Open in Halo")
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: toHalo, evaluatedWith: mark)], timeout: 5), .completed,
                       "dropping Intro.halo didn't say it opens in Halo")
        photo.shot("drop-hand-off")
        let halo = XCUIApplication(bundleIdentifier: "org.creativesuite.halo")
        XCTAssert(halo.wait(for: .runningForeground, timeout: 30), "Halo didn't open Intro.halo")
        halo.terminate()
        photo.app.activate()

        // Step 4: File > Open In ▸ Library: Library imports Sunset.png.
        file.click()
        let openIn = file.menuItems["Open In"]
        XCTAssert(openIn.waitForExistence(timeout: 5), "File has no Open In")
        XCTAssert(openIn.isEnabled, "Open In is off with Sunset.png open and saved")
        openIn.hover()
        let library = file.menuItems["Library"]
        XCTAssert(library.waitForExistence(timeout: 5), "Open In doesn't offer Library")
        library.click()
        let libraryApp = XCUIApplication(bundleIdentifier: "org.creativesuite.library")
        XCTAssert(libraryApp.wait(for: .runningForeground, timeout: 30), "Open In ▸ Library didn't open Library")
        libraryApp.terminate()
    }
}
