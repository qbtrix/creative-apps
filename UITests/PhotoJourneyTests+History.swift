// PhotoJourneyTests+History.swift: history-panel's journeys (docs/blueprints/
// photo/features/history-panel.md, Journey steps 1-4; job RJ-P28). portrait.jpg
// opens; 12 edits (brush strokes) and Window > History list "Open" plus 12
// steps in the inspector's History tab (`suite.history`), the last current. A
// click on the second step shows the image after two steps: Undo names the
// second step and Redo the third, and the step count holds. One more stroke
// drops the ten undone rows and a new "Paint" row is current. Quitting with
// unsaved work and relaunching offers "Restore portrait.jpg from <time>?",
// and Restore shows the 3-step image. Both run on the live
// jump (PH-5) and autosave (PH-6), turned on by PH-7. Shots: `history-*`.
import XCTest

final class PhotoHistoryJourneyTests: XCTestCase {
    /// RJ-P28: 12 edits, a jump back ten steps, one more edit.
    @MainActor func testJumpBackTenSteps() throws {
        let photo = try openPortrait()
        paint(12, photo)
        historyMenuItem(photo).click()
        let panel = photo.element("suite.history")
        XCTAssert(panel.waitForExistence(timeout: 5), "Window > History showed no History tab (suite.history)")
        // Each row is a button read as "Open, applied" (SuiteUI's HistoryPanel), as Design's journey reads it.
        XCTAssert(photo.element("suite.history.row.0").label.hasPrefix("Open"), "the History tab doesn't start at Open")
        XCTAssert(photo.element("suite.history.row.12").waitForExistence(timeout: 5), "the History tab lists no 12th step")
        photo.shot("history-tab")

        // 2. A click on the second step: Undo and Redo name steps 2 and 3, the 12 rows stay.
        photo.element("suite.history.row.2").click()
        XCTAssert(photo.app.buttons["Undo Paint"].waitForExistence(timeout: 5), "after the jump Undo doesn't name step 2")
        XCTAssert(photo.app.buttons["Redo Paint"].exists, "after the jump Redo doesn't name step 3")
        XCTAssert(photo.element("suite.history.row.12").exists, "the jump dropped the undone rows")
        photo.shot("history-jumped")

        // 3. One stroke: the ten undone rows go and the new step is current.
        paint(1, photo)
        XCTAssert(photo.element("suite.history.row.3").waitForExistence(timeout: 5), "the stroke after the jump listed no step 3")
        XCTAssertFalse(photo.element("suite.history.row.4").exists, "the undone rows stayed after a new edit")
        photo.shot("history-new-step")
    }

    /// Quit with unsaved work, relaunch: the offer names portrait.jpg and Restore shows the 3-step image.
    @MainActor func testRestoreAfterQuit() throws {
        let recovery = FileManager.default.temporaryDirectory.appending(path: "photo-history-recovery-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: recovery, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: recovery) }
        var photo = try openPortrait(recoveryDir: recovery)
        paint(3, photo)
        sleep(7)
        photo.app.terminate()
        photo = Journey("Photo", self, arguments: photoArguments(recoveryDir: recovery))
        // Photo keeps its own words for the offer (PhotoRecovery.swift), as the recovery journey reads them.
        let offer = "Restore portrait.jpg from "
        let title = photo.app.staticTexts.matching(
            NSPredicate(format: "label BEGINSWITH %@ OR value BEGINSWITH %@", offer, offer)).firstMatch
        XCTAssert(title.waitForExistence(timeout: 30), "the relaunch didn't offer \(offer)<time>?")
        photo.shot("history-recovery-offer")
        photo.app.buttons["photo.recovery.restore"].click()
        XCTAssert(photo.element("suite.canvas").waitForExistence(timeout: 15), "Restore opened no canvas")
        XCTAssert(photo.app.buttons["Undo Paint"].waitForExistence(timeout: 5), "the restored image has no steps to undo")
        photo.shot("history-restored")
    }

    /// Opens a fresh portrait.jpg in a temp folder.
    @MainActor private func openPortrait(recoveryDir: URL? = nil) throws -> Journey {
        let folder = FileManager.default.temporaryDirectory.appending(path: "photo-history-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let file = folder.appending(path: "portrait.jpg")
        try writeTestPhoto(to: file)
        let photo = Journey("Photo", self, arguments: photoArguments(open: file, recoveryDir: recoveryDir))
        XCTAssert(photo.window(named: "portrait.jpg").waitForExistence(timeout: 30), "portrait.jpg didn't open")
        XCTAssert(photo.element("suite.canvas").waitForExistence(timeout: 5), "no canvas (suite.canvas)")
        return photo
    }

    /// `count` brush strokes, each a step, at different heights.
    @MainActor private func paint(_ count: Int, _ photo: Journey) {
        photo.element("suite.tools").buttons["Brush"].click()
        for stroke in 0..<count {
            let dy = 0.1 + 0.8 * Double(stroke) / Double(max(count, 1))
            photo.drag(on: "suite.canvas", from: CGVector(dx: 0.2, dy: dy), to: CGVector(dx: 0.8, dy: dy))
        }
    }

    /// Window > History.
    @MainActor private func historyMenuItem(_ photo: Journey) -> XCUIElement {
        photo.app.menuBars.menuBarItems["Window"].click()
        let item = photo.app.menuBars.menuItems["History"]
        XCTAssert(item.waitForExistence(timeout: 5), "the Window menu has no History")
        return item
    }
}
