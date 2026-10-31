// AfterGlowJourneyTests+OnboardingStart.swift: the welcome window's start
// page on live (onboarding packet, Journey steps; OB-12 wrote them, OB-13
// runs them). OJ3 `testOpenSampleOpensFlareAndOrdersHome`, on `firstLaunch`:
// Continue, Photos, Continue; Flare's Open sample closes the window and
// brings Flare forward on `<support>/Documents/Samples/Bounce.flare` (shot
// `onboarding-sample-flare`, Flare's key); the home shows the New row in the
// Photos order and Bounce.flare in RECENT (shot `onboarding-home-ordered`);
// a relaunch on the same support folder shows no welcome and the same order.
// OJ4 `testNewDesignFromOnboarding`, on `firstLaunch`: Continue, Continue,
// Design's Blank brings Design forward on an untitled design (shot
// `onboarding-new-design`, Design's key); a relaunch shows no welcome.
//
// Both run live: Bounce.flare ships in the bundle and Flare and Design have
// adopted the suite (Window > Switch To), so a missing sample, window or
// Switch To fails the test (#5947). One skip is left: while Design refuses
// the `.new` hand-off, Blank leaves the welcome open on Design's refusal and
// OJ4 skips naming #5348, the fix; once it lands, OJ4 runs whole. A relaunch leaves out `-SuiteFixture`, which would
// reseed `firstLaunch` and bring the welcome back. Ids are literals, as in
// `AfterGlowOnboardingJourneys`, whose helpers this class reuses.
import XCTest

final class AfterGlowOnboardingStartJourneys: XCTestCase {
    typealias Tour = AfterGlowOnboardingJourneys

    /// OJ3: Open sample opens Bounce.flare in Flare; the home takes the Photos order.
    @MainActor func testOpenSampleOpensFlareAndOrdersHome() throws {
        let suite = SuiteHarness(self)
        let launcher = Tour.launch(suite)
        let welcome = Tour.welcome(launcher)

        // 1. Continue, Photos, Continue: the start page.
        launcher.click("Continue", in: .window)
        XCTAssert(Tour.waitForPage(launcher, "focus"), "Continue led to \(Tour.page(launcher)), not focus")
        Tour.chip(.photos, in: welcome).click()
        XCTAssert(Tour.waitFor { Tour.chip(.photos, in: welcome).isSelected }, "the Photos chip isn't selected")
        launcher.click("Continue", in: .window)
        XCTAssert(Tour.waitForPage(launcher, "start"), "Continue led to \(Tour.page(launcher)), not start")

        let sample = welcome.descendants(matching: .any)["afterglow.onboarding.sample.flare"]
        XCTAssert(sample.waitForExistence(timeout: 5), "Flare's row has no Open sample")
        let bundled = SuiteHarness.bundle.appending(path: "Contents/Resources/Samples/Bounce.flare")
        XCTAssert(FileManager.default.fileExists(atPath: bundled.path), "no Bounce.flare in the bundle's Samples")

        // 2. Open sample: the window closes; the copy is in Documents/Samples; Flare comes forward.
        XCTAssert(sample.isEnabled, "Open sample is disabled though Bounce.flare is bundled")
        sample.click()
        XCTAssert(welcome.waitForNonExistence(timeout: 10), "Open sample didn't close the welcome window")
        let copy = suite.support.appending(path: "Documents/Samples/Bounce.flare")
        XCTAssert(Tour.waitFor { FileManager.default.fileExists(atPath: copy.path) }, "no copy at \(copy.path)")
        XCTAssert(XCUIApplication(bundleIdentifier: SuiteApp.flare.bundleID).wait(for: .runningForeground, timeout: 30),
                  "Open sample didn't bring Flare forward")
        XCTAssertNotEqual(launcher.app.state, .notRunning, "AfterGlow quit when Flare opened")
        let flare = suite.attach(.flare)
        let bounce = flare.app.windows.matching(NSPredicate(format: "title BEGINSWITH 'Bounce'")).firstMatch
        XCTAssert(bounce.waitForExistence(timeout: 10), "Flare's window isn't Bounce")
        flare.shot("onboarding-sample-flare", element: bounce)

        // 3. Back home through Window > Switch To > Home: the Photos order, Bounce.flare in RECENT.
        Self.switchHome(flare)
        XCTAssert(launcher.app.wait(for: .runningForeground, timeout: 10), "the home didn't come forward")
        XCTAssert(Tour.waitFor { Tour.frontTitle(launcher) == "AfterGlow" }, "the home isn't the front window")
        XCTAssertEqual(Self.newRow(launcher), Tour.photosOrder, "the New row isn't in the Photos order")
        XCTAssert(Tour.waitFor { AfterGlowJourneyTests.cardNames(launcher).contains("Bounce.flare") },
                  "RECENT reads \(AfterGlowJourneyTests.cardNames(launcher)), without Bounce.flare")
        launcher.shot("onboarding-home-ordered")

        // 4. Quit and relaunch on the same store: no welcome, the home in front in the same order.
        let again = Self.relaunch(launcher, suite)
        XCTAssertEqual(Self.newRow(again), Tour.photosOrder, "the relaunched New row isn't in the Photos order")
    }

    /// OJ4: Design's Blank opens an untitled design; the tour stays done.
    @MainActor func testNewDesignFromOnboarding() throws {
        let suite = SuiteHarness(self)
        let launcher = Tour.launch(suite)
        let welcome = Tour.welcome(launcher)

        // 1. Continue, Continue: the start page with no focus.
        launcher.click("Continue", in: .window)
        XCTAssert(Tour.waitForPage(launcher, "focus"), "Continue led to \(Tour.page(launcher)), not focus")
        launcher.click("Continue", in: .window)
        XCTAssert(Tour.waitForPage(launcher, "start"), "Continue led to \(Tour.page(launcher)), not start")

        // 2. Design's Blank: the window closes, Design comes forward, AfterGlow keeps running.
        let blank = welcome.descendants(matching: .any)["afterglow.onboarding.new.design.blank"]
        XCTAssert(blank.waitForExistence(timeout: 5), "Design's row has no Blank chip")
        XCTAssert(blank.isEnabled, "Design's Blank chip is disabled")
        blank.click()
        let refusal = welcome.staticTexts["Design can't do that yet."]
        if !welcome.waitForNonExistence(timeout: 10), refusal.exists {
            throw XCTSkip("waits on #5348: Design refuses the welcome's .new hand-off")
        }
        XCTAssert(!welcome.exists, "Blank didn't close the welcome window")
        XCTAssert(XCUIApplication(bundleIdentifier: SuiteApp.design.bundleID).wait(for: .runningForeground, timeout: 30),
                  "Blank didn't bring Design forward")
        XCTAssertNotEqual(launcher.app.state, .notRunning, "AfterGlow quit when Design opened")
        let design = suite.attach(.design)
        XCTAssert(Self.hasSwitchTo(design), "Design's Window has no Switch To")
        let untitled = design.app.windows.matching(NSPredicate(format: "title BEGINSWITH 'Untitled'")).firstMatch
        XCTAssert(untitled.waitForExistence(timeout: 10), "Design's window isn't an untitled design")
        design.shot("onboarding-new-design", element: untitled)

        // 3. Relaunch: no welcome.
        Self.relaunch(launcher, suite)
    }

    // MARK: - Helpers

    /// Whether `journey`'s Window menu has Switch To (SuiteCommands, which an app gets with its adoption).
    @MainActor static func hasSwitchTo(_ journey: Journey) -> Bool {
        let window = journey.app.menuBars.firstMatch.menuBarItems["Window"]
        guard window.waitForExistence(timeout: 5) else { return false }
        window.click()
        let found = window.menuItems["Switch To"].waitForExistence(timeout: 3)
        journey.press(.escape)
        return found
    }

    /// Window > Switch To > Home in another app.
    @MainActor static func switchHome(_ journey: Journey) {
        let window = journey.app.menuBars.firstMatch.menuBarItems["Window"]
        window.click()
        let switchTo = window.menuItems["Switch To"]
        XCTAssert(switchTo.waitForExistence(timeout: 3), "\(journey.name)'s Window has no Switch To")
        switchTo.hover()
        let home = switchTo.menuItems["Home"]
        XCTAssert(home.waitForExistence(timeout: 3), "\(journey.name)'s Switch To has no Home")
        home.click()
    }

    /// The home's New tiles left to right, by their `afterglow.home.new.<app>` ids.
    @MainActor static func newRow(_ launcher: Journey) -> [SuiteApp] {
        let tiles = SuiteApp.apps.map { ($0, launcher.element("afterglow.home.new.\($0.rawValue)")) }
        XCTAssert(tiles.allSatisfy { $0.1.waitForExistence(timeout: 5) }, "the home lacks a New tile")
        return tiles.sorted { $0.1.frame.minX < $1.1.frame.minX }.map(\.0)
    }

    /// Quits AfterGlow and launches it again on the same support folder,
    /// without `-SuiteFixture` or `-SuiteSkipOnboarding`: the home comes up
    /// in front and the welcome window doesn't.
    @discardableResult
    @MainActor static func relaunch(_ launcher: Journey, _ suite: SuiteHarness) -> Journey {
        launcher.app.terminate()
        XCTAssert(launcher.app.wait(for: .notRunning, timeout: 10), "AfterGlow didn't quit")
        let again = Journey(
            bundlePath: SuiteHarness.bundle.path, bundleID: SuiteApp.launcher.bundleID,
            auditKey: SuiteHarness.launcherKey, suite.test)
        again.app.launchArguments = [
            "-ApplePersistenceIgnoreState", "YES", "-SuiteSupportDir", suite.support.path, "-SuitePerfProbe", "YES",
        ]
        again.app.launch()
        again.app.activate()
        XCTAssert(Tour.home(again).waitForExistence(timeout: 30), "the relaunch opened no home")
        XCTAssertFalse(Tour.welcome(again).waitForExistence(timeout: 5), "the welcome window came back on relaunch")
        XCTAssert(Tour.waitFor { Tour.frontTitle(again) == "AfterGlow" }, "the home isn't in front after the relaunch")
        return again
    }
}
