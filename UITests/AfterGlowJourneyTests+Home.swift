// AfterGlowJourneyTests+Home.swift: SJ1 `testHomeFindsAndOpensRecentWork`
// (packet home.md Journey steps; blueprint suite.md 4.2, HM-3a). On
// `weekOfWork` it searches and filters the recents (steps 1 and 2); on
// `missing` it opens the missing Cards.design, removes it and undoes that
// (step 5); on `empty` it reads the empty state (step 6). Steps 3 and 4 are
// switching's (`testOpenRecentBringsAppForward`), so nothing here asserts
// them. The one step that tells a present card from a missing one needs
// Design's documents (#836) and runs last, skipped while they are absent.
import XCTest

extension AfterGlowJourneyTests {
    @MainActor func testHomeFindsAndOpensRecentWork() throws {
        let suite = SuiteHarness(self)
        let home = suite.launch(fixture: "weekOfWork", arguments: ["-SuitePerfProbe", "YES"])
        XCTAssert(home.app.windows.firstMatch.waitForExistence(timeout: 30), "AfterGlow opened no window")
        XCTAssert(Self.waitForCards(home, Self.weekOfWork), "RECENT reads \(Self.cardNames(home)), not \(Self.weekOfWork)")

        // 1. Search "logo": 2 cards.
        let search = home.app.searchFields.firstMatch
        XCTAssert(search.waitForExistence(timeout: 10), "the home has no search field")
        search.click()
        search.typeText("logo")
        let matching = home.element("afterglow.home.matching")
        XCTAssert(matching.waitForExistence(timeout: 5), "no matching count beside RECENT")
        XCTAssert(Self.waitForCards(home, ["Logo.design", "Logo animated.flare"]),
                  "searching logo shows \(Self.cardNames(home))")
        XCTAssertEqual(Self.text(of: matching), "2 items matching \u{201C}logo\u{201D}")
        home.shot("home-sj1-search")

        // 2. The Design chip: 1 card.
        let chip = Self.designChip(home)
        XCTAssert(chip.exists, "no Design chip beside the recents")
        chip.click()
        XCTAssert(Self.waitForCards(home, ["Logo.design"]), "the Design chip shows \(Self.cardNames(home))")
        home.shot("home-sj1-filter")

        // 5. On `missing`: Cards.design is Missing; Return on it says so in place.
        let missing = suite.launch(fixture: "missing", arguments: ["-SuitePerfProbe", "YES"])
        XCTAssert(missing.app.windows.firstMatch.waitForExistence(timeout: 30), "AfterGlow opened no window on missing")
        XCTAssert(Self.waitForCards(missing, Self.weekOfWork), "RECENT reads \(Self.cardNames(missing)) on missing")
        XCTAssert(Self.isMissing(missing, "Cards.design"), "Cards.design isn't marked Missing")
        let logoMissing = Self.isMissing(missing, "Logo.design")
        missing.shot("home-sj1-missing")

        let cards = Self.card(missing, "Cards.design")
        cards.click()
        missing.press(.return)
        let notice = missing.element("afterglow.home.notice")
        XCTAssert(notice.waitForExistence(timeout: 5), "Return on Cards.design shows no notice")
        let sentence = "Cards.design was moved or deleted."
        let said = notice.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@ OR value == %@", sentence, sentence)).firstMatch
        XCTAssert(said.exists, "the notice doesn't say \(sentence)")
        let locate = missing.element("afterglow.home.locate"), remove = missing.element("afterglow.home.remove")
        XCTAssert(locate.exists && locate.label == "Locate…", "the notice has no Locate…")
        XCTAssert(remove.exists && remove.label == "Remove from Recents", "the notice has no Remove from Recents")
        missing.shot("home-sj1-notice")

        // Remove: 7 cards; Edit > Undo Remove from Recents: 8 again.
        remove.click()
        let rest = Self.weekOfWork.filter { $0 != "Cards.design" }
        XCTAssert(Self.waitForCards(missing, rest), "after Remove RECENT reads \(Self.cardNames(missing))")
        missing.shot("home-sj1-removed")
        let edit = missing.app.menuBars.firstMatch.menuBarItems["Edit"]
        edit.click()
        let undo = edit.menuItems["Undo Remove from Recents"]
        XCTAssert(undo.waitForExistence(timeout: 5), "the Edit menu has no Undo Remove from Recents")
        XCTAssert(undo.isEnabled, "Undo Remove from Recents is disabled after a remove")
        undo.click()
        XCTAssert(Self.waitForCards(missing, Self.weekOfWork), "after Undo RECENT reads \(Self.cardNames(missing))")
        missing.shot("home-sj1-undo")

        // 6. On `empty`: Open… is the one prominent button, disabled, and the sentence says why.
        let empty = suite.launch(fixture: "empty", arguments: ["-SuitePerfProbe", "YES"])
        XCTAssert(empty.app.windows.firstMatch.waitForExistence(timeout: 30), "AfterGlow opened no window on empty")
        let open = empty.element("afterglow.home.empty.open")
        XCTAssert(open.waitForExistence(timeout: 10), "the empty home has no Open…")
        XCTAssertFalse(open.isEnabled, "Open… is enabled though it can't route a file yet")
        let primaries = empty.controls()?.controls.filter { $0.role == "primary" } ?? []
        XCTAssertEqual(primaries.map(\.id), ["afterglow.home.empty.open"], "Open… isn't the one prominent button")
        XCTAssertEqual(primaries.first?.reason, Self.openWaits, "Open…'s tooltip isn't HomeMenu.openWaits")
        let first = "No recent work yet. Start something new above."
        let text = empty.app.staticTexts
            .matching(NSPredicate(format: "label BEGINSWITH %@ OR value BEGINSWITH %@", first, first)).firstMatch
        XCTAssert(text.waitForExistence(timeout: 5), "the empty home doesn't say \(first)")
        let lines = Self.text(of: text).split(separator: "\n").map(String.init)
        XCTAssertEqual(lines, [first, Self.openWaits], "the empty sentence's second line isn't Open…'s reason")
        empty.shot("home-sj1-empty")

        // 5, the rest: a file on disk isn't Missing beside the missing Cards.design.
        guard Self.hasFixture("Logo.design") else { throw XCTSkip(Self.waitsOnFixtures) }
        XCTAssertFalse(logoMissing, "on missing, Logo.design was marked Missing though it is on disk")
    }

    /// An element's text: its label, or its value when the label is empty.
    @MainActor static func text(of element: XCUIElement) -> String {
        element.label.isEmpty ? (element.value as? String) ?? "" : element.label
    }

    /// The chip row's Design button: titled Design, not a New tile, right of the sidebar's Design row.
    @MainActor static func designChip(_ home: Journey) -> XCUIElement {
        let sidebar = home.element("suite.sidebar").frame
        let titled = home.app.windows.firstMatch.buttons
            .matching(NSPredicate(format: "label == 'Design' AND NOT (identifier BEGINSWITH 'afterglow.home.new.')"))
        let chip = titled.allElementsBoundByIndex.first { $0.frame.minX >= sidebar.maxX }
        // Past the last match: an element that doesn't exist, so the caller's check fails.
        return chip ?? titled.element(boundBy: titled.count)
    }
}
