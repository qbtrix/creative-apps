// AfterGlowJourneyTests+FirstFiveMinutes.swift: the AfterGlow home's "first
// five minutes" beta gate (Journey+FirstFive.swift has the rules). Three
// first-week tasks, one test each, as a new user does them with no help, on
// `firstLaunch` (an empty store, no recents): get from the welcome window to
// the home, start a new photo from the home's New row, and get back to the
// home from Photo by its window's app switcher. A test that fails on a missing
// or hidden entry point names its `finding` issue. Shots are unaudited:
// `afterglow-first5-<step>`, and Photo's `photo-first5-new-photo`.
import XCTest

final class AfterGlowFirstFiveJourneys: XCTestCase {
    typealias Tour = AfterGlowOnboardingJourneys

    /// The welcome window at first launch, Skip: the home is in front with its New row.
    @MainActor func testFirst5WelcomeToHome() {
        let suite = SuiteHarness(self)
        let launcher = Tour.launch(suite)
        launcher.timeBox()
        launcher.reachable("Skip").click()
        XCTAssert(Tour.welcome(launcher).waitForNonExistence(timeout: 10), "Skip left the welcome window open")
        XCTAssert(Tour.waitFor { Tour.frontTitle(launcher) == "AfterGlow" }, "the home isn't in front after Skip")
        XCTAssert(launcher.element("afterglow.home.new.photo").waitForExistence(timeout: 5), "the home shows no New row")
        launcher.snap("first5-home")
    }

    /// The home's New Photo tile: Photo comes forward on a new image.
    @MainActor func testFirst5NewPhotoFromHome() {
        let suite = SuiteHarness(self)
        _ = newPhoto(suite)
    }

    /// From Photo, the window's switcher Home item: the home comes back to the front.
    @MainActor func testFirst5BackToHome() {
        let suite = SuiteHarness(self)
        let (launcher, photo) = newPhoto(suite)
        let home = photo.element("suite.switcher.home")
        XCTAssert(home.waitForExistence(timeout: 10) && home.isHittable, "Photo shows no way back to the home \(Self.stuckHome)")
        XCTAssert(FirstFive.isPlain(home.label), "Photo's way home reads \(home.label) \(Self.stuckHome)")
        home.click()
        XCTAssert(launcher.app.wait(for: .runningForeground, timeout: 10), "the home didn't come forward \(Self.stuckHome)")
        launcher.snap("first5-back-home")
    }

    /// Where a new user gets stuck, by finding issue.
    private static let stuckNew = "(first five minutes: finding #3648)"
    private static let stuckHome = "(first five minutes: finding #3648)"

    /// The home on `firstLaunch`, then its New Photo tile: Photo in front with a canvas.
    @MainActor private func newPhoto(_ suite: SuiteHarness) -> (Journey, Journey) {
        let launcher = suite.launch(fixture: "firstLaunch")
        launcher.timeBox()
        XCTAssert(Tour.home(launcher).waitForExistence(timeout: 30), "AfterGlow opened no home")
        let tile = launcher.element("afterglow.home.new.photo")
        XCTAssert(tile.waitForExistence(timeout: 10) && tile.isHittable, "the home shows no New Photo \(Self.stuckNew)")
        XCTAssert(FirstFive.isPlain(tile.label), "the New Photo tile reads \(tile.label) \(Self.stuckNew)")
        tile.click()
        XCTAssert(XCUIApplication(bundleIdentifier: SuiteApp.photo.bundleID).wait(for: .runningForeground, timeout: 30),
                  "New Photo didn't bring Photo forward \(Self.stuckNew)")
        let photo = suite.attach(.photo)
        XCTAssert(photo.element("suite.canvas").waitForExistence(timeout: 15), "Photo opened on no new image \(Self.stuckNew)")
        photo.shot("first5-new-photo", element: photo.app.windows.firstMatch, audit: false)
        return (launcher, photo)
    }
}
