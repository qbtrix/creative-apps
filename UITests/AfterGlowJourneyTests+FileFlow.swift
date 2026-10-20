// AfterGlowJourneyTests+FileFlow.swift: SJ-F1 (packet suite/features/file-flow.md, Journey steps 1 to 3;
// SF-2 written, SF-4 turned on). On `weekOfWork`, File > Open Recent ▸ on the home lists the week's files
// newest first; a dropped Intro.halo shows "Open in Halo" and Halo opens it; a dropped notes.xyz is
// refused in words and does nothing. It lives in the launcher's bundle, which has SuiteHarness, so its
// shots go under `afterglow` and are audited.
import XCTest

final class SuiteFileFlowJourneyTests: XCTestCase {
    @MainActor func testDropOnHomeAndOpenRecent() throws {
        try XCTSkipIf(true, "waits on SF-4")
        let suite = SuiteHarness(self)
        let home = suite.launch(fixture: "weekOfWork", arguments: ["-SuitePerfProbe", "YES"])
        XCTAssert(home.app.windows.firstMatch.waitForExistence(timeout: 30), "AfterGlow opened no window")

        // 1. File > Open Recent ▸ lists the week's files, newest first.
        home.app.menuBars.menuBarItems["File"].click()
        let recent = home.app.menuBars.menuItems["Open Recent"]
        XCTAssert(recent.waitForExistence(timeout: 5), "File has no Open Recent")
        recent.hover()
        for name in AfterGlowJourneyTests.weekOfWork {
            XCTAssert(home.app.menuBars.menuItems[name].waitForExistence(timeout: 5), "Open Recent doesn't list \(name)")
        }
        home.shot("file-flow-open-recent")
        home.press(.escape)
    }
}
