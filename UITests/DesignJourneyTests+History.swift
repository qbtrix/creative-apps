// DesignJourneyTests+History.swift: the Journey steps of design/autosave-history
// (docs/blueprints/design/features/autosave-history.md), RJ-D20. View > Show History (DA-2)
// shows SuiteUI's History panel (`suite.history`, rows `suite.history.row.<n>`, 0 for "Open")
// at the window's trailing edge; the toolbar's History button comes with DA-3.
// 1. Open `card.design`, make 12 edits, click History: the panel lists "Open" and 12 steps.
// 2. Click step 2: the canvas shows the card after two edits; later rows dim.
// 3. Make one more edit: the dimmed rows go.
// 4. Force-quit with the edit unsaved, relaunch: the alert offers "Restore the autosaved changes
//    to “card.design”?"; Restore shows the 3-step card, marked edited.
// The toggle (testShowHistoryFromViewMenu): a new file, three rectangles, View > Show History lists
// the base and three steps (shot `design-history-shown`), and View > Hide History takes the panel
// away. testJumpAndRecover (DA-7) runs steps 1 to 4 on live services: the first launch saves
// `cards` as card.design with autosave off, and the next two pass a temp `-SuiteSupportDir`, so
// the window autosaves to `<support>/Design/Recovery/` (DesignRecoveryStore) and the relaunch
// finds the copy. Shots `design-history-panel`, `-jumped`, `-new-step`, `-recovery-offer`, `-restored`.
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
    @MainActor func testJumpAndRecover() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "design-jump-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: "card.design"), support = folder.appending(path: "support")
        let base = ["-DesignServices", "live", "-SuiteWindowSize", "1024x768"], store = ["-SuiteSupportDir", support.path]

        // 1. Save cards as card.design, reopen it, make 12 edits, click History: "Open" and 12 steps.
        var design = Journey("Design", self, arguments: base + ["-DesignFixture", "cards", "-DesignSaveTo", file.path])
        XCTAssert(design.element("suite.canvas").waitForExistence(timeout: 30), "the cards fixture showed no canvas")
        design.press(character: "s", .command)
        XCTAssert(waitUntil { FileManager.default.fileExists(atPath: file.path) }, "⌘S wrote no card.design")
        design.app.terminate()
        design = Journey("Design", self, arguments: base + store + ["-DesignOpenFile", file.path])
        XCTAssert(design.element("suite.canvas").waitForExistence(timeout: 30), "card.design opened no canvas")
        for index in 0..<12 { drawRectangle(design, index) }
        design.element("design.bar.history").click()
        XCTAssert(design.element("suite.history").waitForExistence(timeout: 5), "the History button showed no panel")
        XCTAssert(design.element("suite.history.row.0").label.hasPrefix("Open"), "the panel's first row isn't Open")
        XCTAssert(design.element("suite.history.row.12").waitForExistence(timeout: 5), "the panel lists fewer than 12 steps")
        XCTAssertFalse(design.element("suite.history.row.13").exists, "the panel lists more than 12 steps")
        design.shot("history-panel")

        // 2. Click step 2: it is current, and the later steps stay listed.
        let two = design.element("suite.history.row.2")
        two.click()
        XCTAssert(waitUntil { two.isSelected }, "step 2 isn't current after the click")
        XCTAssert(design.element("suite.history.row.12").exists, "the jump dropped the later steps")
        design.shot("history-jumped")

        // 3. One more edit: the later steps go, a third step is current.
        drawRectangle(design, 12)
        let three = design.element("suite.history.row.3")
        XCTAssert(waitUntil { three.exists && three.isSelected }, "the new edit isn't step 3")
        XCTAssert(design.element("suite.history.row.4").waitForNonExistence(timeout: 5), "the undone steps stayed listed")
        design.shot("history-new-step")

        // 4. Quit with the edit unsaved once it is autosaved, relaunch: Restore brings back card.design, edited.
        let recovery = support.appending(path: "Design/Recovery")
        let autosaved = waitUntil(timeout: 20) {
            ((try? FileManager.default.contentsOfDirectory(atPath: recovery.path)) ?? []).contains { $0.hasSuffix(".design") }
        }
        XCTAssert(autosaved, "no copy autosaved under \(recovery.path)")
        design.app.terminate()
        design = Journey("Design", self, arguments: base + store)
        let offer = "Restore the autosaved changes to \u{201C}card.design\u{201D}?"
        let prompt = design.app.staticTexts.matching(NSPredicate(format: "label == %@ OR value == %@", offer, offer)).firstMatch
        XCTAssert(prompt.waitForExistence(timeout: 30), "the relaunch didn't offer \(offer)")
        design.shot("history-recovery-offer")
        design.app.buttons["suite.recovery.restore"].firstMatch.click()
        XCTAssert(waitUntil(timeout: 10) { self.saveState(design) == "Edited" }, "the restored card reads \(saveState(design)), not Edited")
        XCTAssert(design.element("suite.canvas").exists, "Restore showed no canvas")
        design.shot("history-restored")
    }

    /// Draws the `index`th rectangle with the Rectangle tool, on a 5 × 3 grid over the canvas.
    @MainActor private func drawRectangle(_ design: Journey, _ index: Int) {
        let x = 0.1 + Double(index % 5) * 0.16, y = 0.15 + Double(index / 5) * 0.25
        design.element("suite.tools").buttons["Rectangle"].click()
        design.drag(on: "suite.canvas", from: CGVector(dx: x, dy: y), to: CGVector(dx: x + 0.08, dy: y + 0.12))
    }

    /// The status line's save state ("Saved", "Edited"), or "" when none shows.
    @MainActor private func saveState(_ design: Journey) -> String {
        let label = design.element("design.status.save")
        guard label.exists else { return "" }
        let value = label.value as? String ?? ""
        return value.isEmpty ? label.label : value
    }

    /// Whether `condition` holds within `timeout` seconds.
    @MainActor private func waitUntil(timeout: Double = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        } while Date() < deadline
        return condition()
    }

    /// Opens the View menu and returns its item `title`.
    @MainActor private func viewItem(_ design: Journey, _ title: String) -> XCUIElement {
        design.app.menuBars.firstMatch.menuBarItems["View"].click()
        return design.app.menuBars.firstMatch.menuItems[title].firstMatch
    }
}
