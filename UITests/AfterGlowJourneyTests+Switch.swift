// AfterGlowJourneyTests+Switch.swift: switching's journeys (packet
// switching.md Journey steps, SW-4a): SJ3 `testSwitchKeepsEachAppAsLeft`,
// `testOpenRecentBringsAppForward` and `testCrashIsolation`, on the HM-0
// harness (`SuiteHarness`), so every shot goes under `afterglow`.
//
// The bundle compiles only SuiteModel's Values, so SwitchMenu's titles and
// sentences are literals here. What the launcher does alone runs now: its
// Window > Switch To items and their Control-Command digits, and a switch
// launching an app as its own process while the home keeps running. The
// steps that need Flare or Design to host suite documents and add the
// shared switcher wait on their adoptions (A-FL-1 #861, A-DE-1 #862) and
// fixtures (A-FL-0 #837, A-DE-0 #836); they run last and throw XCTSkip
// while those are absent.
import AppKit
import XCTest

extension AfterGlowJourneyTests {
    /// Why a step that needs Flare and Design adopted is skipped.
    static let waitsOnAdoption = "waits on #861 (A-FL-1), #862 (A-DE-1), #837 (A-FL-0), #836 (A-DE-0)"
    /// SwitchMenu's titles on the home, in order: its own item, then the apps.
    static let homeSwitchItems = ["Show AfterGlow Window", "Flare", "Design", "Photo", "Library", "Halo"]

    /// The process `app` runs as once a switch has started it, by the URL of
    /// its running bundle: `XCUIApplication(bundleIdentifier:)` raises when
    /// Launch Services hasn't registered the id yet, as it can for an app the
    /// launcher just started by path. Fails and returns nil when no such
    /// process appears within `timeout` seconds.
    /// Whether `app`'s Window menu has Switch To, which brings ⌃⌘0-5 (SuiteCommands).
    @MainActor static func hasSwitchTo(_ app: XCUIApplication) -> Bool {
        let window = app.menuBars.firstMatch.menuBarItems["Window"]
        guard window.waitForExistence(timeout: 5) else { return false }
        window.click()
        defer { app.typeKey(.escape, modifierFlags: []) }
        return window.menuItems["Switch To"].waitForExistence(timeout: 3)
    }

    /// The home's running strip reading exactly `text` (a plain Text reads
    /// its words as its value on macOS, so both are matched).
    @MainActor static func runningStrip(_ home: Journey, reads text: String) -> XCUIElement {
        home.app.staticTexts.matching(NSPredicate(format: "label == %@ OR value == %@", text, text)).firstMatch
    }

    @MainActor func switched(to app: SuiteApp, timeout: TimeInterval = 30) -> XCUIApplication? {
        let deadline = Date(timeIntervalSinceNow: timeout)
        repeat {
            let process = NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID)
                .first(where: { !$0.isTerminated && $0.bundleURL != nil })
            if let url = process?.bundleURL { return XCUIApplication(url: url) }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.25))
        } while Date() < deadline
        XCTFail("\(app.displayName) (\(app.bundleID)) didn't start within \(Int(timeout)) s")
        return nil
    }

    /// SJ3: each app keeps its state across switches.
    @MainActor func testSwitchKeepsEachAppAsLeft() throws {
        let suite = SuiteHarness(self)
        let home = suite.launch(fixture: "weekOfWork", arguments: ["-SuitePerfProbe", "YES"])
        XCTAssert(home.app.windows.firstMatch.waitForExistence(timeout: 30), "AfterGlow opened no window")

        // Window > Switch To on the home: its own item disabled, the five apps after it.
        let window = home.app.menuBars.firstMatch.menuBarItems["Window"]
        XCTAssert(window.waitForExistence(timeout: 5), "the home has no Window menu")
        window.click()
        let switchTo = window.menuItems["Switch To"]
        XCTAssert(switchTo.waitForExistence(timeout: 3), "Window has no Switch To")
        switchTo.hover()
        for title in Self.homeSwitchItems {
            XCTAssert(switchTo.menuItems[title].waitForExistence(timeout: 3), "Switch To has no \(title)")
        }
        XCTAssertFalse(switchTo.menuItems["Show AfterGlow Window"].isEnabled, "the home's own item is enabled")
        XCTAssert(switchTo.menuItems["Design"].isEnabled, "Switch To > Design is disabled on the home")
        home.shot("switch-sj3-menu")
        home.press(.escape)
        home.press(.escape)

        // ⌃⌘2 opens Design as its own process; the home keeps running.
        home.press(character: "2", [.control, .command])
        guard let design = switched(to: .design) else { return }
        XCTAssert(design.wait(for: .runningForeground, timeout: 30), "⌃⌘2 didn't bring Design forward")
        XCTAssertNotEqual(home.app.state, .notRunning, "the home quit when Design opened")

        // ⌃⌘0 from Design: the home comes forward, Design keeps running. Design
        // has the shortcut once it adds SuiteCommands' Switch To (A-DE-1).
        guard Self.hasSwitchTo(design) else { throw XCTSkip(Self.waitsOnAdoption) }
        design.typeKey("0", modifierFlags: [.control, .command])
        XCTAssert(home.app.wait(for: .runningForeground, timeout: 10), "⌃⌘0 in Design didn't bring the home forward")
        XCTAssertNotEqual(design.state, .notRunning, "Design quit when the home came forward")
        home.shot("switch-sj3-home")

        // 1-5: Bounce.flare at frame 12, the switcher, ⌃⌘1 / ⌃⌘0 keeping state, ⌘W and Show Flare Window.
        throw XCTSkip(Self.waitsOnAdoption)
    }

    /// A recent card opens in its app, which comes forward; the home stays running.
    @MainActor func testOpenRecentBringsAppForward() throws {
        let suite = SuiteHarness(self)
        let home = suite.launch(fixture: "weekOfWork", arguments: ["-SuitePerfProbe", "YES"])
        XCTAssert(home.app.windows.firstMatch.waitForExistence(timeout: 30), "AfterGlow opened no window")
        XCTAssert(Self.waitForCards(home, Self.weekOfWork), "RECENT reads \(Self.cardNames(home)), not \(Self.weekOfWork)")

        let search = home.app.searchFields.firstMatch
        XCTAssert(search.waitForExistence(timeout: 10), "the home has no search field")
        search.click()
        search.typeText("logo")
        let chip = Self.designChip(home)
        XCTAssert(chip.exists, "no Design chip beside the recents")
        chip.click()
        XCTAssert(Self.waitForCards(home, ["Logo.design"]), "the Design chip shows \(Self.cardNames(home))")
        home.shot("switch-open-recent-filter")

        // Return on Logo.design: Design forward with its window titled Logo.design.
        guard Self.hasFixture("Logo.design") else { throw XCTSkip(Self.waitsOnAdoption) }
        Self.card(home, "Logo.design").click()
        home.press(.return)
        let design = suite.attach(.design)
        XCTAssert(design.app.wait(for: .runningForeground, timeout: 30), "Design didn't come forward")
        XCTAssert(design.app.windows["Logo.design"].waitForExistence(timeout: 10), "Design's window isn't Logo.design")
        XCTAssertNotEqual(home.app.state, .notRunning, "the home quit when Design opened Logo.design")
        // ⌃⌘0 in Design needs its Switch To menu.
        throw XCTSkip(Self.waitsOnAdoption)
    }

    /// One app's crash leaves the others and the home as they were.
    @MainActor func testCrashIsolation() throws {
        let suite = SuiteHarness(self)
        let home = suite.launch(fixture: "weekOfWork", arguments: ["-SuitePerfProbe", "YES"])
        XCTAssert(home.app.windows.firstMatch.waitForExistence(timeout: 30), "AfterGlow opened no window")

        // Flare and Design each run as their own process.
        home.press(character: "1", [.control, .command])
        guard let flare = switched(to: .flare) else { return }
        XCTAssert(flare.wait(for: .runningForeground, timeout: 30), "⌃⌘1 didn't open Flare")
        home.app.activate()
        _ = home.app.wait(for: .runningForeground, timeout: 10)
        home.press(character: "2", [.control, .command])
        guard let design = switched(to: .design) else { return }
        XCTAssert(design.wait(for: .runningForeground, timeout: 30), "⌃⌘2 didn't open Design")

        // Design's dirty document goes here, before the kill, once Design hosts
        // suite documents (A-DE-1, A-DE-0); until then its window stands in.
        XCTAssert(design.windows.firstMatch.waitForExistence(timeout: 10), "Design shows no window")

        // SIGKILL Flare: Design and the home keep running.
        guard let process = NSRunningApplication.runningApplications(withBundleIdentifier: SuiteApp.flare.bundleID)
            .first(where: { !$0.isTerminated }), process.forceTerminate() else {
            throw XCTSkip("This runner can't signal another process; run testCrashIsolation locally.")
        }
        XCTAssert(flare.wait(for: .notRunning, timeout: 10), "Flare survived SIGKILL")
        XCTAssertNotEqual(design.state, .notRunning, "Design quit when Flare was killed")
        XCTAssertNotEqual(home.app.state, .notRunning, "the home quit when Flare was killed")
        XCTAssert(design.windows.firstMatch.exists, "Design's window closed when Flare was killed")

        // Before the relaunch: the home's running strip drops Flare within 1 s.
        home.app.activate()
        XCTAssert(home.app.wait(for: .runningForeground, timeout: 10), "the home didn't come forward")
        XCTAssert(Self.runningStrip(home, reads: "Design").waitForExistence(timeout: 1),
                  "the running strip still lists Flare 1 s after its SIGKILL")
        home.shot("switch-crash-home")

        // ⌃⌘1 from the home launches Flare cold.
        home.press(character: "1", [.control, .command])
        XCTAssert(flare.wait(for: .runningForeground, timeout: 30), "⌃⌘1 didn't launch Flare again")

        // Design's dirty dot unchanged after the kill.
        throw XCTSkip(Self.waitsOnAdoption)
    }
}
