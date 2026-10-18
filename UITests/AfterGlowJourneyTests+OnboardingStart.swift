// AfterGlowJourneyTests+OnboardingStart.swift: the welcome window's start
// page on live (onboarding packet, Journey steps; OB-12 writes them, OB-13
// runs them). OJ3 `testOpenSampleOpensFlareAndOrdersHome`, on `firstLaunch`:
// Continue, "Photos", Continue; Flare's Open sample closes the window and
// brings Flare forward on `<support>/Documents/Samples/Bounce.flare` (shot
// `onboarding-sample-flare`, Flare's audit key); Window > Switch To > Home
// shows the New row in the Photos order and Bounce.flare in RECENT (shot
// `onboarding-home-ordered`); a relaunch on the same support folder shows no
// welcome. OJ4 `testNewDesignFromOnboarding`, on `firstLaunch`: Continue,
// Continue, Design's "Blank" opens an untitled design (shot
// `onboarding-new-design`, Design's key); a relaunch shows no welcome. Both
// need switching's Window > Switch To and the bundled samples, so they skip
// until OB-13 turns them on.
import XCTest

final class AfterGlowOnboardingStartJourneys: XCTestCase {
    @MainActor func testOpenSampleOpensFlareAndOrdersHome() throws {
        throw XCTSkip("waits on OB-13")
    }

    @MainActor func testNewDesignFromOnboarding() throws {
        throw XCTSkip("waits on OB-13")
    }
}
