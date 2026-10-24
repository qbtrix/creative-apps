// AfterGlowJourneyTests+Previews.swift: HJ-ST (shared-thumbnails; ST-4 written, ST-8 turns it on).
// On `weekOfWork` every Recent card says it shows a preview or its app's mark, and at least one a preview.
import AppKit
import XCTest

final class HomePreviewsJourneyTests: XCTestCase {
    @MainActor func testHomeShowsDocumentPreviews() throws {
        throw XCTSkip("waits on ST-8")
        let home = SuiteHarness(self).launch(fixture: "weekOfWork", arguments: ["-SuitePerfProbe", "YES"])
        XCTAssert(home.app.windows.firstMatch.waitForExistence(timeout: 30), "AfterGlow opened no window")
        XCTAssert(AfterGlowJourneyTests.waitForCards(home, AfterGlowJourneyTests.weekOfWork), "RECENT doesn't list the week")
        let cards = home.app.descendants(matching: .any).matching(AfterGlowJourneyTests.cardPredicate)
        let shown = { (card: XCUIElement) -> Bool in
            let value = card.value as? String ?? ""
            return value.contains(", preview") || value.contains(", app mark")
        }
        let answered = expectation(for: NSPredicate { _, _ in cards.allElementsBoundByIndex.allSatisfy(shown) },
                                   evaluatedWith: NSNull())
        wait(for: [answered], timeout: 15)
        let values = cards.allElementsBoundByIndex.map { $0.value as? String ?? "" }
        XCTAssert(values.contains { $0.contains(", preview") }, "no card shows a preview: \(values)")
        home.shot("home-recents-previews-live")
    }
}
