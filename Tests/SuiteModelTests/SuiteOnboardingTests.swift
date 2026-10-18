// SuiteOnboardingTests.swift: the live OnboardingFlowing (onboarding OB-7's
// acceptance row, written first by OB-2; disabled until OB-7's bodies).
import SuiteModel
import Testing

@Suite(.timeLimit(.minutes(1))) struct SuiteOnboardingTests {
    let flow = SuiteOnboarding()
    let version = SuiteOnboarding.version

    @Test(.disabled("waits on OB-7")) func showsUntilTheCurrentVersionIsDone() {
        #expect(flow.shouldShow(SuitePreferences(), version: version))
        #expect(flow.shouldShow(SuitePreferences(onboardingDoneVersion: version - 1), version: version))
        #expect(!flow.shouldShow(SuitePreferences(onboardingDoneVersion: version), version: version))
        #expect(flow.shouldShow(SuitePreferences(onboardingDoneVersion: version), version: version + 1))
    }

    @Test(.disabled("waits on OB-7")) func finishingRecordsTheVersionAndPutsTheFocusFirst() {
        let done = flow.finishing(SuitePreferences(revision: 4, units: .millimeters), focus: .photos, version: version)
        #expect(done.onboardingDoneVersion == version && !flow.shouldShow(done, version: version))
        #expect(Array(done.homeOrder.prefix(2)) == [.library, .photo])
        #expect(done.revision == 4 && done.units == .millimeters)
        let none = flow.finishing(SuitePreferences(homeOrder: [.halo, .flare, .design, .photo, .library]), focus: nil, version: version)
        #expect(none.homeOrder == SuiteApp.apps && none.onboardingDoneVersion == version)
    }

    @Test(.disabled("waits on OB-7")) func everyFocusOrderKeepsAllFiveApps() {
        #expect(SuiteOnboarding.order(for: nil) == SuiteApp.apps)
        for focus in OnboardingFocus.allCases {
            let order = SuiteOnboarding.order(for: focus)
            #expect(order.count == SuiteApp.apps.count && Set(order) == Set(SuiteApp.apps), "\(focus)")
            #expect(order == flow.finishing(SuitePreferences(), focus: focus, version: version).homeOrder, "\(focus)")
        }
        #expect(SuiteOnboarding.order(for: .animation).first == .flare)
        #expect(SuiteOnboarding.order(for: .motion).first == .halo)
    }
}
