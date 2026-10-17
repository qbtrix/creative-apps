// AfterGlowJourneyTests.swift: the home's journeys (packet home.md Journey
// steps; blueprint suite.md 4.2, HM-3a). SJ0 `testLaunchShowsHomeAndEveryMenu`
// lives here, SJ1 in `+Home`, both on the HM-0 harness (`SuiteHarness`), so
// every shot goes under `afterglow` and is audited.
//
// The bundle compiles only SuiteModel's Values (project.yml), so HomeMenu's,
// HomeBuilder's and SuiteFixtures' strings are literals here: the
// `weekOfWork` recents newest first, the menu titles of LauncherCommands and
// HomeMenu, `HomeMenu.openWaits`. A card is found by its
// `afterglow.home.card.<fileID>` identifier, whose file id is a path ending in
// the file's name. ThumbnailGrid is lazy, so `cardNames` scrolls the grid to
// read every card, then scrolls it back.
//
// `UITests/Fixtures/suite` holds Logo.design and Cards.design once A-DE-0
// (#836) exports them; until then every card is Missing, so the steps that
// need a present file run last and throw XCTSkip while the file is absent.
import XCTest

final class AfterGlowJourneyTests: XCTestCase {
    /// SuiteFixtures.weekOfWorkFiles' recents, newest first.
    static let weekOfWork = [
        "Logo.design", "Cards.design", "Bounce.flare", "Intro.halo",
        "beach.ora", "Title.flare", "Sunset.png", "Logo animated.flare",
    ]
    /// HomeMenu.openWaits: why Open… can't act yet.
    static let openWaits = "Opening files from AfterGlow isn't available yet."
    /// Why a step that needs Design's documents on disk is skipped.
    static let waitsOnFixtures = "waits on #836 (A-DE-0)"
    /// The app-defined items of each menu but the app menu (LauncherCommands,
    /// HomeMenu, SuiteCommands); Help defines none.
    static let menuItems: [String: [String]] = [
        "File": ["New", "Open…", "Open Recent"],
        "Edit": ["Undo Remove from Recents", "Remove from Recents", "Cut", "Copy", "Add from Clipboard", "Select All"],
        "View": ["Show Sidebar", "Show Inspector", "Larger Thumbnails", "Smaller Thumbnails"],
        "Window": ["Switch To", "Assets"],
    ]
    /// The app menu's own item (LauncherCommandsUpdate).
    static let appMenuItems = ["Check for Updates…"]

    static var cardPredicate: NSPredicate { NSPredicate(format: "identifier BEGINSWITH 'afterglow.home.card.'") }

    /// SJ0: the home on launch, every menu, and the `afterglow.*` controls.
    @MainActor func testLaunchShowsHomeAndEveryMenu() throws {
        let suite = SuiteHarness(self)
        let home = suite.launch(fixture: "weekOfWork", arguments: ["-SuitePerfProbe", "YES"])
        XCTAssert(home.app.windows.firstMatch.waitForExistence(timeout: 30), "AfterGlow opened no window")
        XCTAssert(home.app.wait(for: .runningForeground, timeout: 10), "the home isn't frontmost")

        // 1. Sidebar, the five New tiles, RECENT newest first, the empty strip.
        let sidebar = home.element("suite.sidebar")
        XCTAssert(sidebar.waitForExistence(timeout: 10), "the home has no sidebar")
        for row in ["Home", "Assets"] + SuiteApp.apps.map(\.displayName) {
            XCTAssert(sidebar.staticTexts[row].exists, "the sidebar has no \(row) row")
        }
        for app in SuiteApp.apps {
            XCTAssert(home.element("afterglow.home.new.\(app.rawValue)").exists, "no New tile for \(app.displayName)")
        }
        XCTAssert(Self.waitForCards(home, Self.weekOfWork), "RECENT reads \(Self.cardNames(home)), not \(Self.weekOfWork)")
        XCTAssert(Self.strip(home).waitForExistence(timeout: 5), "the running strip doesn't read No apps running")
        home.shot("home-sj0-launch")

        // 2. Every menu opens; each holds its app-defined items.
        home.openEachMenu(expecting: ["File": "New", "View": "Larger Thumbnails", "Window": "Switch To"])
        let appMenu = home.app.menuBars.firstMatch.menuBarItems.element(boundBy: 1)
        XCTAssertEqual(Self.missingItems(Self.appMenuItems, in: appMenu, home), [], "the app menu lacks items")
        for (title, items) in Self.menuItems.sorted(by: { $0.key < $1.key }) {
            let menu = home.app.menuBars.firstMatch.menuBarItems[title]
            XCTAssertEqual(Self.missingItems(items, in: menu, home), [], "the \(title) menu lacks items")
        }

        // 3. suite.controls: each disabled control says why; each enabled one on screen takes a click.
        let entries = home.controls()?.controls.filter { $0.id.hasPrefix("afterglow.") } ?? []
        XCTAssertFalse(entries.isEmpty, "suite.controls lists no afterglow.* control")
        for entry in entries where !entry.enabled {
            XCTAssertFalse((entry.reason ?? "").isEmpty, "\(entry.id) is disabled and says nothing")
        }
        // New tiles launch apps and the inspector's buttons leave the home: SJ19 sweeps those.
        for entry in entries where entry.enabled && !entry.id.hasPrefix("afterglow.home.new.")
            && !entry.id.hasPrefix("afterglow.home.inspector.") {
            let control = home.element(entry.id)
            guard control.exists, control.isHittable else { continue }
            control.click()
            home.press(.escape)
            home.app.activate()
            _ = home.app.wait(for: .runningForeground, timeout: 10)
        }
        home.shot("home-sj0-controls")

        // 1, the rest: Design's documents are on disk, so their cards aren't Missing.
        guard Self.hasFixture("Cards.design"), Self.hasFixture("Logo.design") else {
            throw XCTSkip(Self.waitsOnFixtures)
        }
        for name in ["Logo.design", "Cards.design"] {
            XCTAssertFalse(Self.isMissing(home, name), "\(name) is marked Missing though it is on disk")
        }
    }

    // MARK: - Helpers shared with +Home

    /// Whether `name` is in UITests/Fixtures/suite.
    @MainActor static func hasFixture(_ name: String) -> Bool {
        FileManager.default.fileExists(atPath: SuiteHarness.fixtureDocuments.appending(path: name).path)
    }

    /// The running strip's "No apps running".
    @MainActor static func strip(_ home: Journey) -> XCUIElement {
        home.app.staticTexts.matching(NSPredicate(format: "label == 'No apps running' OR value == 'No apps running'"))
            .firstMatch
    }

    /// The card of the file `name`.
    @MainActor static func card(_ home: Journey, _ name: String) -> XCUIElement {
        let predicate = NSPredicate(
            format: "identifier BEGINSWITH 'afterglow.home.card.' AND identifier ENDSWITH %@", "/" + name)
        return home.app.descendants(matching: .any).matching(predicate).firstMatch
    }

    /// Whether the card of `name` reads Missing (its value is "Missing, <age>").
    @MainActor static func isMissing(_ home: Journey, _ name: String) -> Bool {
        ((card(home, name).value as? String) ?? "").hasPrefix("Missing")
    }

    /// Every card's file name in grid order (rows top to bottom, left to
    /// right), scrolling the lazy grid down to read them all and back after.
    @MainActor static func cardNames(_ home: Journey) -> [String] {
        let cards = home.app.descendants(matching: .any).matching(cardPredicate)
        let grid = home.app.windows.firstMatch.scrollViews.containing(cardPredicate).firstMatch
        var names: [String] = []
        var scrolled: CGFloat = 0
        for pass in 0..<6 {
            let before = names.count
            let visible = cards.allElementsBoundByIndex.sorted {
                ($0.frame.minY, $0.frame.minX) < ($1.frame.minY, $1.frame.minX)
            }
            for card in visible {
                let name = String(card.identifier.split(separator: "/").last ?? "")
                if !name.isEmpty, !names.contains(name) { names.append(name) }
            }
            guard grid.exists, pass == 0 || names.count > before else { break }
            grid.scroll(byDeltaX: 0, deltaY: -150)
            scrolled -= 150
        }
        if scrolled != 0, grid.exists { grid.scroll(byDeltaX: 0, deltaY: -scrolled) }
        return names
    }

    /// Whether the cards read `expected`, in order, within about five seconds.
    @MainActor static func waitForCards(_ home: Journey, _ expected: [String]) -> Bool {
        for _ in 0..<10 {
            if cardNames(home) == expected { return true }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return cardNames(home) == expected
    }

    /// The items of `items` that `menu` doesn't hold; opens it to look and closes it.
    @MainActor static func missingItems(_ items: [String], in menu: XCUIElement, _ home: Journey) -> [String] {
        guard menu.waitForExistence(timeout: 5) else { return items }
        menu.click()
        _ = menu.menuItems.firstMatch.waitForExistence(timeout: 3)
        let missing = items.filter { !menu.menuItems[$0].exists }
        home.press(.escape)
        return missing
    }
}
