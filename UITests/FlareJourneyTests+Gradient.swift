// FlareJourneyTests+Gradient.swift: FJ-G1 (gradient-fill FG-4, live since FG-7). On the gradient-circle sample
// (`FlareFixtures.gradientCircle` on live services) it selects the circle (FILL shows the stop bar, not the word
// "Gradient"), recolours the middle stop red, types 90 in the angle row, undoes both one step each, then picks Radial
// for the solid rectangle. Shots are `flare-fg-<step>`.
import XCTest

final class FlareGradientJourneyTests: XCTestCase {
    @MainActor func testEditImportedGradient() throws {
        let flare = Journey("Flare", self, arguments: ["-FlareSample", "gradient-circle"])
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let stage = flare.element("suite.canvas")
        // 1. Select the circle: FILL shows the stop bar in the gradient's colours.
        flare.element("flare.timeline").buttons["Circle"].click()
        XCTAssert(flare.element("suite.gradient").waitForExistence(timeout: 5), "FILL shows no gradient editor")
        flare.shot("fg-1-circle")
        // 2. Middle stop red: the stage changes.
        let before = stage.screenshot().pngRepresentation
        flare.element("suite.gradient.stop.1").click()
        flare.element("suite.gradient.color").textFields.firstMatch.typeText("FF0000\r")
        XCTAssert(stage.screenshot().pngRepresentation != before, "the stage looks the same after the stop colour")
        flare.shot("fg-2-red")
        // 3. Angle 90: the gradient runs top to bottom.
        flare.element("suite.gradient.angle").textFields.firstMatch.typeText("90\r")
        flare.shot("fg-3-angle")
        // 4. Undo twice: the angle, then the colour.
        flare.press(character: "z", .command)
        flare.shot("fg-4a-undo-angle")
        flare.press(character: "z", .command)
        XCTAssert(stage.screenshot().pngRepresentation == before, "two undos left the circle changed")
        // 5. A solid rectangle takes Radial.
        flare.element("flare.timeline").buttons["Rectangle"].click()
        flare.element("suite.gradient.type.radial").click()
        XCTAssert(flare.element("suite.gradient").waitForExistence(timeout: 5), "Radial showed no gradient editor")
        flare.shot("fg-5-radial")
    }
}
