// SuiteJourneyTests+History.swift: the gallery's `history-panel` page (Sources/SuiteUI/Gallery/GalleryHistoryPanel.swift),
// the Journey steps 1 to 4 of docs/blueprints/suiteui/features/autosave-history.md (numbered below), in Library,
// shot under `suiteui`. Rows are `suite.history.row.<n>`, 0 for "Open"; the page logs `history.jump {"index": <n>}`
// to `suite.gallery.log`. AH-2 wrote it skipped; AH-4 turned it on over AH-3's panel: the rows sit in `suite.history`,
// the current one carries the selected trait, a click jumps, Up and Down move the selection and Return jumps.
import XCTest

final class SuiteHistoryJourneyTests: XCTestCase {
    /// The page's listing: "Open" and eleven steps, eight applied (GalleryHistoryPanel.listing).
    private static let steps = 11

    @MainActor func testHistoryPanelJumps() throws {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "index"])
        XCTAssert(gallery.element("suite.gallery.index").waitForExistence(timeout: 30), "no gallery index")
        gallery.element("suite.gallery.index.history-panel").click() // 1. "Open" and eleven steps, the eighth current.
        XCTAssert(gallery.element("suite.gallery.history-panel").waitForExistence(timeout: 10), "no suite.gallery.history-panel")
        XCTAssert(gallery.element("suite.history").waitForExistence(timeout: 10), "no suite.history panel on the page")
        for n in 0...Self.steps where !gallery.element("suite.history.row.\(n)").exists { XCTFail("no suite.history.row.\(n)") }
        expectCurrent(gallery, 8)
        gallery.shot("history-panel-open")
        gallery.element("suite.history.row.4").click() // 2. The fourth step is current; one jump logged.
        expectLog(gallery, "history.jump {\"index\": 4}", "the click on step 4 logged no jump")
        expectCurrent(gallery, 4)
        gallery.shot("history-panel-jumped")
        gallery.app.typeKey(.downArrow, modifierFlags: []) // 3. Down, Down, Return: the sixth is current.
        gallery.app.typeKey(.downArrow, modifierFlags: [])
        gallery.app.typeKey(.return, modifierFlags: [])
        expectLog(gallery, "history.jump {\"index\": 6}", "Down, Down, Return logged no jump to 6")
        expectCurrent(gallery, 6)
        let moveLabel = gallery.element("suite.history.row.6").label
        XCTAssertEqual(moveLabel, "Step 6 of 11, Move, applied", "VoiceOver reads step 6 as \(moveLabel)")
        for _ in 0..<8 { gallery.app.typeKey(.upArrow, modifierFlags: []) } // Up past "Open" stays on "Open".
        gallery.app.typeKey(.return, modifierFlags: [])
        expectLog(gallery, "history.jump {\"index\": 0}", "Up past Open and Return logged no jump to 0")
        gallery.element("suite.history.row.6").click()
        expectLog(gallery, "history.jump {\"index\": 6}", "the click on step 6 logged no jump")
        gallery.element("suite.history.row.0").click() // 4. "Open": nothing applied, every step dims.
        expectLog(gallery, "history.jump {\"index\": 0}", "the click on Open logged no jump to 0")
        expectCurrent(gallery, 0)
        gallery.shot("history-panel-base")
    }

    /// Row `index` is selected and reads applied; every row after it reads not applied.
    @MainActor private func expectCurrent(_ gallery: Journey, _ index: Int) {
        let row = gallery.element("suite.history.row.\(index)")
        let wait = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isSelected == true"), object: row)
        XCTAssertEqual(XCTWaiter().wait(for: [wait], timeout: 5), .completed, "row \(index) isn't current")
        for n in 0...Self.steps where n > index {
            let label = gallery.element("suite.history.row.\(n)").label
            XCTAssert(label.hasSuffix("not applied"), "row \(n) reads \(label), not undone, with row \(index) current")
        }
    }

    /// Waits up to five seconds for the page's last log line to be `text`.
    @MainActor private func expectLog(_ gallery: Journey, _ text: String, _ message: String) {
        let log = gallery.element("suite.gallery.log")
        let wait = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label ENDSWITH %@", text), object: log)
        XCTAssertEqual(XCTWaiter().wait(for: [wait], timeout: 5), .completed, "\(message); the log reads \(log.value ?? "nothing")")
    }
}
