// AfterGlowJourneyTests+AIAccess.swift (afterglow-mcp MC-12): the approval journey
// (sheet, Allow Once, chip, Stop and the re-ask, an empty Window > AI Access…) on the fake request;
// turned on by MC-13. MC-10 swaps the fake for the live channel behind the same views.
// The bundle compiles only SuiteModel's Values, so AIAccessPrompt's copy is literal.
import XCTest

extension AfterGlowJourneyTests {
    @MainActor func testAIAccessApproval() throws {
        let suite = SuiteHarness(self)
        let home = suite.launch(fixture: "weekOfWork", arguments: ["-AIAccessDemoRequest", "Test Client"])
        XCTAssert(home.app.windows.firstMatch.waitForExistence(timeout: 30), "AfterGlow opened no window")

        // The sheet asks, naming the client and the app.
        let sheet = home.app.sheets.firstMatch
        XCTAssert(sheet.waitForExistence(timeout: 10), "no approval sheet for the demo request")
        XCTAssert(sheet.staticTexts["Allow the AI assistant “Test Client” to work in AfterGlow?"].exists, "the sheet doesn't name the client and app")
        let help = "Allow Once lasts until “Test Client” disconnects. Always Allow remembers “Test Client” for AfterGlow."
        XCTAssert(sheet.staticTexts[help].exists, "the sheet doesn't tell the two allows apart")
        for title in ["Deny", "Always Allow"] { XCTAssert(sheet.buttons[title].exists, "the sheet has no \(title)") }
        home.shot("ai-access-sheet")

        // Allow Once: the sheet closes and the chip says who is in control.
        home.click("Allow Once", in: .sheet)
        XCTAssert(sheet.waitForNonExistence(timeout: 5), "the sheet stayed after Allow Once")
        let chip = home.element("suite.aiaccess.chip")
        XCTAssert(chip.waitForExistence(timeout: 5), "no Controlled by chip after Allow Once")
        // Falls back to the value the way Home's journey does (#262).
        XCTAssertEqual(chip.label.isEmpty ? (chip.value as? String) ?? "" : chip.label, "Controlled by Test Client")
        home.shot("ai-access-chip")

        // Stop: the chip goes, and the client's next request asks again.
        home.element("suite.aiaccess.stop").click()
        XCTAssert(chip.waitForNonExistence(timeout: 5), "the chip stayed after Stop")
        XCTAssert(sheet.waitForExistence(timeout: 5), "the next request didn't ask again after Stop")
        home.shot("ai-access-reask")
        home.click("Allow Once", in: .sheet)
        XCTAssert(sheet.waitForNonExistence(timeout: 5), "the sheet stayed after the second Allow Once")
        XCTAssert(chip.waitForExistence(timeout: 5), "no chip after the second Allow Once")
        home.element("suite.aiaccess.stop").click()
        XCTAssert(chip.waitForNonExistence(timeout: 5), "the chip stayed after the second Stop")

        // Window > AI Access… lists no grant: an allow-once isn't remembered.
        let window = home.app.menuBars.firstMatch.menuBarItems["Window"]
        window.click()
        let item = window.menuItems["AI Access…"]
        XCTAssert(item.waitForExistence(timeout: 3), "Window has no AI Access…")
        item.click()
        XCTAssert(home.app.windows["AI Access"].waitForExistence(timeout: 5), "AI Access… opened no window")
        XCTAssert(home.app.staticTexts["No AI Clients"].exists, "the list isn't empty after an allow-once")
        home.shot("ai-access-list")
    }
}
