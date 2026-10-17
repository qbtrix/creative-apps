// FlareJourneyTests+NewSheet.swift: J2, step 3 of layers-files (LF-3), on live
// services. ⌘N shows the New Animation sheet; Vertical 9:16, 30 fps, Create:
// the artboard's height over width is within 0.01 of 1920 / 1080 and the
// timecode totals 05:00. One shot per step, `flare-new-sheet-<step>`.
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

        // 2. Vertical 9:16, then 30 fps.
        flare.click("Vertical 9:16", in: .sheet)
        let rate = flare.element("flare.new.fps")
        XCTAssert(rate.waitForExistence(timeout: 5), "no Frame Rate (flare.new.fps)")
        rate.click()
        let thirty = flare.app.menuItems["30 fps"].firstMatch
        XCTAssert(thirty.waitForExistence(timeout: 5), "Frame Rate offers no 30 fps")
        thirty.click()
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
}
