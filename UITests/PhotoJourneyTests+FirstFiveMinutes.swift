// PhotoJourneyTests+FirstFiveMinutes.swift: Photo's "first five minutes"
// beta gate (Journey+FirstFive.swift has the rules). Three first-week tasks,
// one test each, as a new user does them with no help: open a photo and crop
// it, brighten it, export it as a JPEG. Open… is checked in the empty window's
// toolbar, then -PhotoOpenFile stands in for picking the file in the system
// panel; -PhotoExportTo does the same for Export's folder. A test that fails
// on a missing or hidden entry point names its `finding` issue. Shots are
// `photo-first5-<step>`.
import XCTest

final class PhotoFirstFiveJourneys: XCTestCase {
    /// Open a photo (Open… in the toolbar), pick Crop from the tools, drag, Apply Crop: the image is smaller.
    @MainActor func testFirst5OpenAndCrop() throws {
        let fresh = Journey("Photo", self, arguments: photoArguments() + FirstFive.freshProfile())
        fresh.timeBox()
        fresh.reachable("Open…")
        fresh.snap("first5-empty")
        fresh.app.terminate()

        let photo = try open(exportTo: nil)
        photo.reachable(menu: ["Image", "Straighten…"])
        photo.app.typeKey(.escape, modifierFlags: [])
        photo.reachable("Crop", in: photo.element("suite.tools")).click()
        photo.drag(on: "suite.canvas", from: CGVector(dx: 0.25, dy: 0.25), to: CGVector(dx: 0.75, dy: 0.75))
        photo.reachable("Apply Crop").click()
        let original = labelled("800 × 600 px", photo)
        XCTAssert(original.waitForNonExistence(timeout: 10), "Apply Crop left the photo 800 × 600 px")
        photo.snap("first5-cropped")
    }

    /// Brighten the photo: a control a new user would call Brightness, in the window or one menu deep.
    @MainActor func testFirst5Brighten() throws {
        let photo = try open(exportTo: nil)
        photo.timeBox()
        let named = NSPredicate(format: "label CONTAINS[c] 'Brightness' OR title CONTAINS[c] 'Brightness'")
        let brightness = photo.app.windows.firstMatch.sliders.matching(named).firstMatch
        // Not in the panel: one menu deep (Image, Layer and the rest) opens it.
        let menus = photo.app.menuBars.firstMatch.menuBarItems
        for index in 1..<menus.count where !brightness.waitForExistence(timeout: 2) {
            menus.element(boundBy: index).click()
            let item = menus.element(boundBy: index).menus.firstMatch.children(matching: .menuItem).matching(named).firstMatch
            if item.waitForExistence(timeout: 1), item.isEnabled { item.click() } else { photo.app.typeKey(.escape, modifierFlags: []) }
        }
        XCTAssert(brightness.waitForExistence(timeout: 5),
                  "a new user finds no Brightness control in the window \(Self.stuckBrightness)")
        let before = photo.element("suite.canvas").screenshot().pngRepresentation
        brightness.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: brightness.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5)))
        XCTAssert(FirstFive.wait(5) { photo.element("suite.canvas").screenshot().pngRepresentation != before },
                  "dragging Brightness didn't change the photo")
        photo.snap("first5-brighter")
    }

    /// File > Export…, JPEG, Export: an 800 × 600 JPEG in the export folder.
    @MainActor func testFirst5ExportJPEG() throws {
        let exports = FirstFive.folder("photo-first5-exports")
        let photo = try open(exportTo: exports)
        photo.timeBox()
        photo.choose(menu: ["File", "Export…"])
        let jpeg = photo.app.sheets.radioButtons["JPEG"]
        XCTAssert(jpeg.waitForExistence(timeout: 5), "the Export sheet offers no JPEG")
        jpeg.click()
        photo.snap("first5-export-sheet")
        photo.reachable("Export", in: photo.app.sheets.firstMatch).click()
        let file = FirstFive.file(in: exports, ext: "jpg") ?? FirstFive.file(in: exports, ext: "jpeg", timeout: 1)
        let written = try XCTUnwrap(file, "Export wrote no JPEG into the export folder")
        XCTAssertEqual(Array(try Data(contentsOf: written).prefix(3)), [0xFF, 0xD8, 0xFF], "\(written.lastPathComponent) isn't a JPEG")
        let size = FirstFive.pixelSize(of: written)
        XCTAssert(size?.width == 800 && size?.height == 600, "the JPEG is \(String(describing: size)), not 800 × 600")
    }

    /// Where a new user gets stuck, by finding issue.
    private static let stuckBrightness = "(first five minutes: finding #3527)"

    /// Photo on a fresh profile with an 800 × 600 beach.png open, as Open… would leave it.
    @MainActor private func open(exportTo: URL?) throws -> Journey {
        let file = FirstFive.folder("photo-first5").appending(path: "beach.png")
        try writeTestPhoto(to: file)
        let photo = Journey("Photo", self, arguments: photoArguments(open: file, exportTo: exportTo) + FirstFive.freshProfile())
        XCTAssert(photo.window(named: "beach.png").waitForExistence(timeout: 30), "beach.png didn't open")
        return photo
    }

    @MainActor private func labelled(_ text: String, _ photo: Journey) -> XCUIElement {
        photo.app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }
}
