// AfterGlowJourneyTests+Onboarding.swift: OJ1 `testFirstLaunchShowsAndSkips`
// and OJ2 `testFocusOrdersStarters` (onboarding packet, Journey steps; OB-6),
// and XJ-SS `testOpenEverySample` (sample-files packet, SS-7): each app's
// Open sample opens its sample (shot `onboarding-sample-<app>`, audited once
// the app has Switch To), a sample not in the bundle is disabled with its
// reason, and RECENT lists the opened samples (shot `onboarding-samples-home`).
// Both launch AfterGlow on `firstLaunch` without `-SuiteSkipOnboarding`, so
// the "Welcome to AfterGlow" window presents itself over the home. Every
// click is a mouse click on a titled button (`Journey.click`) or a menu item
// found by title; keys appear only in OJ2 step 6, Escape for Skip and Return
// for Continue. Every shot goes under `afterglow` and is audited.
//
// Its own class, as the HM-0 smoke file is, so it doesn't lean on the home's
// AfterGlowJourneyTests. The bundle compiles only SuiteModel's Values, so
// OnboardingControls' ids (`afterglow.onboarding.<name>`) are literals here;
// OnboardingFocus and SuiteApp come from Values. The page element's value is
// the page id: `apps`, `focus`, `start`, read from its label (#262).
import XCTest

final class AfterGlowOnboardingJourneys: XCTestCase {
    static let title = "Welcome to AfterGlow"
    static let prefix = "afterglow.onboarding."
    /// SuiteOnboarding.order(for: .photos): the start page's rows top to bottom.
    static let photosOrder: [SuiteApp] = [.library, .photo, .flare, .design, .halo]

    /// OJ1: the welcome window at first launch, Skip, Help reopens it, the close button leaves.
    @MainActor func testFirstLaunchShowsAndSkips() {
        let suite = SuiteHarness(self)
        let launcher = Self.launch(suite)
        let welcome = Self.welcome(launcher)

        // 1. Page 1 over the home: the five apps and the Rendering line.
        XCTAssert(Self.home(launcher).waitForExistence(timeout: 10), "no home window under the welcome window")
        XCTAssert(Self.waitForPage(launcher, "apps"), "page 1 reads \(Self.page(launcher)), not apps")
        for app in SuiteApp.apps {
            XCTAssert(Self.text(containing: app.displayName, in: welcome).exists, "page 1 doesn't name \(app.displayName)")
        }
        XCTAssert(Self.text(containing: "Rendering is", in: welcome).exists, "page 1 has no Rendering line")
        Self.expectNoDeadControls(in: welcome, page: "apps")
        let homeControls = Self.controls(in: Self.home(launcher))
        launcher.shot("onboarding-welcome")

        // 2. Skip: the window closes, the home is frontmost, its controls unchanged.
        launcher.click("Skip", in: .window)
        XCTAssert(welcome.waitForNonExistence(timeout: 10), "Skip didn't close the welcome window")
        XCTAssert(Self.waitFor { Self.frontTitle(launcher) == "AfterGlow" }, "the home isn't frontmost after Skip")
        XCTAssertEqual(Self.controls(in: Self.home(launcher)), homeControls, "Skip changed the home's suite.controls")
        launcher.shot("onboarding-skipped")

        // 3. Help > Welcome to AfterGlow: back on page 1.
        Self.reopen(launcher)
        XCTAssert(Self.waitForPage(launcher, "apps"), "the reopened window reads \(Self.page(launcher)), not apps")
        launcher.shot("onboarding-reopened")

        // 4. The close button: the window closes, the home stays.
        let close = welcome.buttons[XCUIIdentifierCloseWindow]
        XCTAssert(close.waitForExistence(timeout: 5), "the welcome window has no close button")
        close.click()
        XCTAssert(welcome.waitForNonExistence(timeout: 10), "the close button didn't close the welcome window")
        XCTAssert(Self.home(launcher).exists, "the home closed with the welcome window")
    }

    /// OJ2: a focus orders the starter rows; Back keeps it; the empty home; Escape and Return parity.
    @MainActor func testFocusOrdersStarters() {
        let suite = SuiteHarness(self)
        let launcher = Self.launch(suite)
        let welcome = Self.welcome(launcher)

        // 1. Continue: five chips, none selected; Continue stays enabled.
        launcher.click("Continue", in: .window)
        XCTAssert(Self.waitForPage(launcher, "focus"), "Continue led to \(Self.page(launcher)), not focus")
        for focus in OnboardingFocus.allCases {
            let chip = Self.chip(focus, in: welcome)
            XCTAssert(chip.exists, "no \(focus.rawValue) chip on the focus page")
            XCTAssertFalse(chip.isSelected, "the \(focus.rawValue) chip is selected before a click")
        }
        XCTAssert(welcome.descendants(matching: .any)[Self.prefix + "continue"].isEnabled, "Continue is disabled with no focus")
        launcher.shot("onboarding-focus")

        // 2. Photos, then Continue.
        // By identifier: the chip reads "Photos: Library, Photo" since #3021.
        Self.chip(.photos, in: welcome).click()
        XCTAssert(Self.waitFor { Self.chip(.photos, in: welcome).isSelected }, "the Photos chip isn't selected after a click")
        launcher.click("Continue", in: .window)

        // 3. The start page: Library then Photo first, then Flare, Design, Halo; presets and Open sample on each row.
        XCTAssert(Self.waitForPage(launcher, "start"), "Continue led to \(Self.page(launcher)), not start")
        let samples = SuiteApp.apps.map { welcome.descendants(matching: .any)[Self.prefix + "sample." + $0.rawValue] }
        for (app, sample) in zip(SuiteApp.apps, samples) {
            XCTAssert(sample.exists, "\(app.displayName)'s row has no Open sample")
            XCTAssertEqual(sample.label, "Open sample", "\(app.displayName)'s sample button isn't titled Open sample")
            let presets = welcome.descendants(matching: .any)
                .matching(NSPredicate(format: "identifier BEGINSWITH %@", Self.prefix + "new." + app.rawValue + "."))
            XCTAssertGreaterThan(presets.count, 0, "\(app.displayName)'s row has no preset chip")
        }
        let order = zip(SuiteApp.apps, samples).sorted { $0.1.frame.minY < $1.1.frame.minY }.map(\.0)
        XCTAssertEqual(order, Self.photosOrder, "the Photos focus orders the rows \(order.map(\.displayName))")
        Self.expectNoDeadControls(in: welcome, page: "start")
        launcher.shot("onboarding-start")

        // 4. Back keeps the focus.
        launcher.click("Back", in: .window)
        XCTAssert(Self.waitForPage(launcher, "focus"), "Back led to \(Self.page(launcher)), not focus")
        XCTAssert(Self.chip(.photos, in: welcome).isSelected, "Back dropped the Photos focus")
        launcher.click("Continue", in: .window)
        XCTAssert(Self.waitForPage(launcher, "start"), "Continue led to \(Self.page(launcher)), not start")

        // 5. Start from an empty home: the window closes, the home is frontmost.
        launcher.click("Start from an empty home", in: .window)
        XCTAssert(welcome.waitForNonExistence(timeout: 10), "Start from an empty home didn't close the window")
        XCTAssert(Self.waitFor { Self.frontTitle(launcher) == "AfterGlow" }, "the home isn't frontmost")
        launcher.shot("onboarding-empty-home")

        // 6. Keyboard parity: Escape is Skip, Return is Continue.
        Self.reopen(launcher)
        launcher.press(.escape)
        XCTAssert(welcome.waitForNonExistence(timeout: 10), "Escape didn't close the welcome window")
        Self.reopen(launcher)
        XCTAssert(Self.waitForPage(launcher, "apps"), "the reopened window reads \(Self.page(launcher)), not apps")
        launcher.press(.return)
        XCTAssert(Self.waitForPage(launcher, "focus"), "Return led to \(Self.page(launcher)), not focus")
    }

    /// XJ-SS (sample-files SS-7): every tour tile's Open sample opens its app on its sample; Home's recents list them.
    @MainActor func testOpenEverySample() throws {
        let suite = SuiteHarness(self)
        let launcher = Self.launch(suite)
        let welcome = Self.welcome(launcher)
        var missing: [String] = [], listed: [String] = []
        for (index, app) in SuiteApp.apps.enumerated() {
            // 1. Continue, Continue: the start page; after the first sample, Help > Welcome to AfterGlow first.
            if index > 0 {
                launcher.app.activate()
                Self.reopen(launcher)
                XCTAssert(Self.waitForPage(launcher, "apps"), "the reopened window reads \(Self.page(launcher)), not apps")
            }
            launcher.click("Continue", in: .window)
            XCTAssert(Self.waitForPage(launcher, "focus"), "Continue led to \(Self.page(launcher)), not focus")
            launcher.click("Continue", in: .window)
            XCTAssert(Self.waitForPage(launcher, "start"), "Continue led to \(Self.page(launcher)), not start")
            if index == 0 { launcher.shot("onboarding-samples-all-present") }

            // 2. The tile: enabled when its sample is bundled; otherwise disabled with its reason, and Escape leaves.
            let file = Self.sampleFiles[app] ?? ""
            let id = Self.prefix + "sample." + app.rawValue
            let tile = welcome.descendants(matching: .any)[id]
            XCTAssert(tile.waitForExistence(timeout: 5), "\(app.displayName)'s row has no Open sample")
            let bundled = SuiteHarness.bundle.appending(path: "Contents/Resources/Samples/" + file)
            guard FileManager.default.fileExists(atPath: bundled.path) else {
                XCTAssertFalse(tile.isEnabled, "Open sample is enabled with no \(file) in the bundle")
                let entry = Self.controls(in: welcome)?.controls.first { $0.id == id }
                XCTAssertEqual(entry?.reason, "The \(app.displayName) sample isn't in this build.", "\(file)'s reason")
                missing.append(file)
                launcher.press(.escape)
                XCTAssert(welcome.waitForNonExistence(timeout: 10), "Escape didn't close the welcome window")
                continue
            }

            // 3. Open sample: the window closes, the copy lands in Documents/Samples, the app comes forward on it.
            XCTAssert(tile.isEnabled, "\(app.displayName)'s Open sample is disabled though \(file) is bundled")
            tile.click()
            XCTAssert(welcome.waitForNonExistence(timeout: 10), "\(app.displayName)'s Open sample didn't close the window")
            let copy = suite.support.appending(path: "Documents/Samples/" + file)
            XCTAssert(Self.waitFor { FileManager.default.fileExists(atPath: copy.path) }, "no copy at \(copy.path)")
            XCTAssert(XCUIApplication(bundleIdentifier: app.bundleID).wait(for: .runningForeground, timeout: 30),
                      "Open sample didn't bring \(app.displayName) forward")
            XCTAssertNotEqual(launcher.app.state, .notRunning, "AfterGlow quit when \(app.displayName) opened")
            let opened = suite.attach(app)
            let adopted = AfterGlowOnboardingStartJourneys.hasSwitchTo(opened)
            // Library imports Sunset.png into its catalog, so its window keeps the catalog's title.
            let stem = String(file.prefix { $0 != "." })
            let window = app == .library ? opened.app.windows.firstMatch
                : opened.app.windows.matching(NSPredicate(format: "title BEGINSWITH %@", stem)).firstMatch
            if adopted {
                XCTAssert(window.waitForExistence(timeout: 10), "\(app.displayName)'s window isn't \(stem)")
                listed.append(file)
            }
            opened.shot("onboarding-sample-" + app.rawValue, element: adopted ? window : opened.app.windows.firstMatch, audit: adopted)
        }

        // 4. Home: RECENT lists each sample an adopted app opened.
        launcher.app.activate()
        XCTAssert(launcher.app.wait(for: .runningForeground, timeout: 10), "the home didn't come forward")
        XCTAssert(Self.waitFor { Self.frontTitle(launcher) == "AfterGlow" }, "the home isn't the front window")
        for file in listed {
            XCTAssert(Self.waitFor { AfterGlowJourneyTests.cardNames(launcher).contains(file) },
                      "RECENT reads \(AfterGlowJourneyTests.cardNames(launcher)), without \(file)")
        }
        launcher.shot("onboarding-samples-home")
        // Every sample ships (beach.ora since #5947), so a missing one is a failure, not a skip.
        XCTAssert(missing.isEmpty, "\(missing.joined(separator: ", ")) isn't in the bundle's Samples")
    }

    // MARK: - Helpers

    /// The file each app's Open sample opens: SampleCatalog.samples, as literals (the bundle compiles only Values).
    static let sampleFiles: [SuiteApp: String] = [
        .flare: "Bounce.flare", .design: "Cards.design", .photo: "beach.ora", .library: "Sunset.png", .halo: "Intro.halo",
    ]

    /// Launches on `firstLaunch` with the welcome window allowed and the probes on; waits for it in front.
    @MainActor static func launch(_ suite: SuiteHarness) -> Journey {
        let launcher = suite.launch(fixture: "firstLaunch", arguments: ["-SuitePerfProbe", "YES"], skipOnboarding: false)
        XCTAssert(welcome(launcher).waitForExistence(timeout: 30), "no \(title) window at first launch")
        XCTAssert(waitFor { frontTitle(launcher) == title }, "the welcome window isn't frontmost: \(frontTitle(launcher))")
        return launcher
    }

    @MainActor static func welcome(_ launcher: Journey) -> XCUIElement {
        launcher.app.windows.matching(NSPredicate(format: "title == %@", title)).firstMatch
    }

    @MainActor static func home(_ launcher: Journey) -> XCUIElement {
        launcher.app.windows.matching(NSPredicate(format: "title == 'AfterGlow'")).firstMatch
    }

    /// The title of the frontmost window, the one `Journey.shot` and `click(in: .window)` use.
    @MainActor static func frontTitle(_ launcher: Journey) -> String {
        launcher.app.windows.firstMatch.title
    }

    /// The page id, the page element's value.
    @MainActor static func page(_ launcher: Journey) -> String {
        (welcome(launcher).descendants(matching: .any)[prefix + "page"].label as String?) ?? "none"
    }

    @MainActor static func waitForPage(_ launcher: Journey, _ id: String) -> Bool {
        waitFor { page(launcher) == id }
    }

    @MainActor static func chip(_ focus: OnboardingFocus, in window: XCUIElement) -> XCUIElement {
        window.descendants(matching: .any)[prefix + "focus." + focus.rawValue]
    }

    @MainActor static func text(containing text: String, in window: XCUIElement) -> XCUIElement {
        window.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text)).firstMatch
    }

    /// Help > Welcome to AfterGlow, clicked by title; the window comes back in front.
    @MainActor static func reopen(_ launcher: Journey) {
        let help = launcher.app.menuBars.firstMatch.menuBarItems["Help"]
        XCTAssert(help.waitForExistence(timeout: 5), "the menu bar has no Help menu")
        help.click()
        let item = help.menuItems[title]
        XCTAssert(item.waitForExistence(timeout: 5), "the Help menu has no \(title)")
        item.click()
        XCTAssert(welcome(launcher).waitForExistence(timeout: 10), "Help > \(title) opened no window")
        XCTAssert(waitFor { frontTitle(launcher) == title }, "the reopened welcome window isn't frontmost")
    }

    /// A window's `suite.controls` document; nil when it publishes none.
    @MainActor static func controls(in window: XCUIElement) -> ControlDocument? {
        let probe = window.descendants(matching: .any)["suite.controls"].firstMatch
        guard probe.waitForExistence(timeout: 5) else { return nil }
        return try? JSONDecoder().decode(ControlDocument.self, from: Data(probe.label.utf8))
    }

    /// Every `afterglow.onboarding.*` control the welcome window lists is enabled or says why.
    @MainActor static func expectNoDeadControls(in window: XCUIElement, page: String) {
        let listed = controls(in: window)?.controls.filter { $0.id.hasPrefix(prefix) } ?? []
        XCTAssertFalse(listed.isEmpty, "the welcome window's suite.controls lists no onboarding control on \(page)")
        for entry in listed where !entry.enabled {
            XCTAssertFalse((entry.reason ?? "").isEmpty, "\(entry.id) is disabled on \(page) and says nothing")
        }
        if page == "start" {
            for app in SuiteApp.apps {
                XCTAssert(listed.contains { $0.id == prefix + "sample." + app.rawValue },
                          "suite.controls doesn't list \(app.displayName)'s Open sample")
            }
        }
    }

    /// Whether `condition` holds within `timeout` seconds, spinning the run loop between looks.
    @MainActor static func waitFor(_ timeout: TimeInterval = 10, _ condition: () -> Bool) -> Bool {
        let deadline = Date(timeIntervalSinceNow: timeout)
        while !condition() {
            guard Date() < deadline else { return false }
            RunLoop.current.run(until: Date(timeIntervalSinceNow: 0.25))
        }
        return true
    }
}
