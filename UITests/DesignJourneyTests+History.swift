// DesignJourneyTests+History.swift: the Journey steps of design/autosave-history
// (docs/blueprints/design/features/autosave-history.md), RJ-D20. View > Show History (DA-2)
// shows SuiteUI's History panel (`suite.history`, rows `suite.history.row.<n>`, 0 for "Open")
// at the window's trailing edge; the toolbar's History button comes with DA-3.
// 1. Open `card.design`, make 12 edits, click History: the panel lists "Open" and 12 steps.
// 2. Click step 2: the canvas shows the card after two edits; later rows dim.
// 3. Make one more edit: the dimmed rows go.
// 4. Force-quit with the edit unsaved, relaunch: the alert offers "Restore the autosaved changes
//    to “card.design”?"; Restore shows the 3-step card, marked edited.
// DA-2 writes steps 2 to 4 skipped: the jump and the recovery bytes are stubs until DA-5, the
// autosave until SuiteUI's AH-8, and DA-7 turns them on over live services. The toggle runs now
// (testShowHistoryFromViewMenu): a new file, three rectangles, View > Show History lists the base
// and three steps (shot `design-history-shown`), and View > Hide History takes the panel away.
import XCTest

final class DesignHistoryJourneyTests: XCTestCase {
    /// View > Show History shows the panel with a row per step; View > Hide History hides it.
    @MainActor func testShowHistoryFromViewMenu() {
        let design = Journey("Design", self)
        design.app.typeKey("n", modifierFlags: .command)
        XCTAssert(design.element("suite.canvas").waitForExistence(timeout: 30), "New File showed no canvas")
        for index in 0..<3 {
            let x = 0.15 + Double(index) * 0.2
            design.element("suite.tools").buttons["Rectangle"].click()
            design.drag(on: "suite.canvas", from: CGVector(dx: x, dy: 0.3), to: CGVector(dx: x + 0.1, dy: 0.45))
        }
        XCTAssert(design.app.buttons["Undo Add Rectangle"].waitForExistence(timeout: 5), "drawing made no undo step")
        let panel = design.element("suite.history")
        XCTAssertFalse(panel.exists, "the History panel shows before View > Show History")
        let show = viewItem(design, "Show History")
        XCTAssert(show.waitForExistence(timeout: 3) && show.isEnabled, "View has no enabled Show History with a window open")
        show.click()
        XCTAssert(panel.waitForExistence(timeout: 5), "View > Show History showed no History panel (suite.history)")
        for row in 0...3 {
            XCTAssert(design.element("suite.history.row.\(row)").waitForExistence(timeout: 5), "the panel lists no row \(row)")
        }
        XCTAssertFalse(design.element("suite.history.row.4").exists, "the panel lists more than three steps")
        design.shot("history-shown")
        let hide = viewItem(design, "Hide History")
        XCTAssert(hide.waitForExistence(timeout: 3), "View doesn't offer Hide History while the panel shows")
        hide.click()
        XCTAssert(panel.waitForNonExistence(timeout: 5), "View > Hide History left the History panel on screen")
    }

    /// Steps 1 to 4: twelve edits, a jump to step 2, one more edit, then a force-quit and Restore.
    @MainActor func testJumpAndRecover() throws { throw XCTSkip("waits on DA-7: the jump and autosave are stubs") }

    /// Opens the View menu and returns its item `title`.
    @MainActor private func viewItem(_ design: Journey, _ title: String) -> XCUIElement {
        design.app.menuBars.firstMatch.menuBarItems["View"].click()
        return design.app.menuBars.firstMatch.menuItems[title].firstMatch
    }
}
