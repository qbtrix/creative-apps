// AfterGlowJourneyTests+Smoke.swift: proves the suite harness (HM-0,
// AfterGlowJourneyTests+Harness.swift). AfterGlow.app launches on the
// `empty` fixture with the suite flags, the home window is up, and
// `attach(.launcher)` shoots and audits it under `afterglow`; the harness's
// teardown then fails if any suite process is still running.
import XCTest

final class AfterGlowSmokeJourneys: XCTestCase {
    @MainActor func testLauncherLaunchesOnEmpty() {
        let suite = SuiteHarness(self)
        let launched = suite.launch(fixture: "empty")
        XCTAssert(launched.app.windows.firstMatch.waitForExistence(timeout: 30), "AfterGlow opened no window")
        XCTAssert(launched.element("suite.sidebar").waitForExistence(timeout: 10), "the home window has no sidebar")

        let home = suite.attach(.launcher)
        XCTAssertEqual(home.name, "afterglow", "the launcher's shots must count under afterglow")
        XCTAssert(home.element("suite.sidebar").exists, "attach(.launcher) doesn't see the home window")
        home.shot("smoke-empty")
    }
}
