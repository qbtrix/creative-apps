// FlareJourneyTests+NewSheet.swift: J2, step 3 of layers-files (LF-3), on live
// services. ⌘N shows the shared New Document sheet (document-setup DS-14) on Flare's presets;
// Vertical 9:16 (30 fps), Create: the artboard's height over width is within 0.01 of 1920 / 1080 and the
// timecode totals 05:00. One shot per step, `flare-new-sheet-<step>`. FJ-DS (document-setup DS-13/DS-14):
// `testDocumentSettingsLater` opens `bounce` (550 × 400), File > Document Settings… shows the shared sheet, 1080 ×
// 1080 and Apply make the stage square.
import XCTest

final class FlareNewSheetJourneys: XCTestCase {
    @MainActor func testNewAnimationFromPreset() {
        let flare = Journey("Flare", self)
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")

        // 1. ⌘N: the sheet.
        flare.press(character: "n", .command)
        let sheet = flare.app.sheets.firstMatch
        XCTAssert(sheet.waitForExistence(timeout: 10), "⌘N showed no sheet")
        flare.shot("new-sheet-1-open")

        // 2. The shared sheet's preset menu: Vertical 9:16, which is 30 fps.
        let preset = flare.element("suite.newdoc.preset")
        XCTAssert(preset.waitForExistence(timeout: 5), "no Preset menu (suite.newdoc.preset)")
        preset.click()
        let vertical = flare.app.menuItems["Vertical 9:16"].firstMatch
        XCTAssert(vertical.waitForExistence(timeout: 5), "Preset offers no Vertical 9:16")
        vertical.click()
        XCTAssertEqual(flare.element("suite.newdoc.pixels").value as? String, "1080 × 1920 px")
        flare.shot("new-sheet-2-vertical")

        // 3. Create: a 1080 × 1920 artboard and a 05:00 timeline.
        flare.click("Create", in: .sheet)
        XCTAssert(sheet.waitForNonExistence(timeout: 5), "Create left the sheet open")
        let artboard = flare.element("suite.canvas.artboard")
        XCTAssert(artboard.waitForExistence(timeout: 10), "Create showed no artboard (suite.canvas.artboard)")
        let ratio = artboard.frame.width > 0 ? artboard.frame.height / artboard.frame.width : 0
        XCTAssertEqual(ratio, 1920.0 / 1080.0, accuracy: 0.01, "the artboard isn't 1080 × 1920")
        let timecode = flare.element("flare.timeline.timecode")
        XCTAssert(timecode.waitForExistence(timeout: 5), "no timecode (flare.timeline.timecode)")
        XCTAssert(timecode.label.hasSuffix("/ 05:00"), "the timecode reads \(timecode.label), not a 05:00 total")
        flare.shot("new-sheet-3-created")
    }

    @MainActor func testDocumentSettingsLater() {
        let flare = Journey("Flare", self, arguments: ["-FlareFixture", "bounce"])
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")

        // 1. File > Document Settings…: the shared sheet in settings mode.
        flare.app.menuBars.menuBarItems["File"].click()
        let item = flare.app.menuItems["Document Settings…"].firstMatch
        XCTAssert(item.waitForExistence(timeout: 5), "File has no Document Settings…")
        item.click()
        XCTAssert(flare.element("suite.newdoc").waitForExistence(timeout: 10), "no Document Settings sheet (suite.newdoc)")
        XCTAssertEqual(flare.element("suite.newdoc.pixels").value as? String, "550 × 400 px")
        flare.shot("document-settings-1-open")

        // 2. 1080 × 1080, then Apply.
        for id in ["width", "height"] {
            let field = flare.element("suite.newdoc.\(id)")
            field.doubleClick()
            flare.press(character: "a", .command)
            flare.app.typeText("1080")
        }
        XCTAssertEqual(flare.element("suite.newdoc.pixels").value as? String, "1080 × 1080 px")
        flare.element("suite.newdoc.create").click()
        XCTAssert(flare.element("suite.newdoc").waitForNonExistence(timeout: 5), "Apply left the sheet open")

        // 3. The stage is square.
        let artboard = flare.element("suite.canvas.artboard")
        XCTAssert(artboard.waitForExistence(timeout: 10), "no artboard (suite.canvas.artboard)")
        let ratio = artboard.frame.width > 0 ? artboard.frame.height / artboard.frame.width : 0
        XCTAssertEqual(ratio, 1, accuracy: 0.01, "the artboard isn't 1080 × 1080")
        flare.shot("document-settings-2-square")
    }
}
