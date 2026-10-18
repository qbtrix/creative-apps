// OnboardingLaunchTests.swift: whether the first launch shows the welcome
// window (onboarding OB-7's acceptance row, written first by OB-2; disabled
// until OB-7's bodies). "-SuiteSkipOnboarding YES" always wins.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel
import Testing

@Suite(.timeLimit(.minutes(1))) struct OnboardingLaunchTests {
    let flow = SuiteOnboarding()
    let done = SuitePreferences(onboardingDoneVersion: SuiteOnboarding.version)

    func presents(_ args: [String], _ stored: SuitePreferences?) -> Bool {
        OnboardingLaunch.presents(arguments: args, stored: stored, flow: flow)
    }

    func emptyStore() -> FileStore {
        FileStore(folder: FileManager.default.temporaryDirectory.appendingPathComponent("OnboardingLaunchTests-\(UUID().uuidString)").path)
    }

    @Test(.disabled("waits on OB-7")) func skipFlagYesHidesWhateverIsStored() {
        for stored in [nil, SuitePreferences(), done] {
            #expect(!presents(["AfterGlow", "-SuiteSkipOnboarding", "YES"], stored))
        }
    }

    @Test(.disabled("waits on OB-7")) func otherwiseTheFlowAnswersOnWhatIsStored() {
        for args in [[], ["-SuiteSkipOnboarding", "NO"], ["-SuiteSkipOnboarding"], ["YES", "-SuiteSkipOnboarding"]] {
            #expect(presents(args, nil), "\(args)")
            #expect(presents(args, SuitePreferences(onboardingDoneVersion: SuiteOnboarding.version - 1)), "\(args)")
            #expect(!presents(args, done), "\(args)")
        }
        #expect(OnboardingLaunch.presents(arguments: [], stored: done, flow: flow, version: SuiteOnboarding.version + 1))
    }

    @Test(.disabled("waits on OB-7")) func storedReadsWhatTheStoreWrote() throws {
        let store = emptyStore()
        #expect(OnboardingLaunch.stored(in: store) == nil)
        let written = SuitePreferences(onboardingDoneVersion: 1, homeOrder: [.library, .photo, .flare, .design, .halo])
        let revision = try store.write("preferences.json", written, expecting: 0)
        let read = try #require(OnboardingLaunch.stored(in: store))
        #expect(read.onboardingDoneVersion == 1 && read.homeOrder == written.homeOrder && read.revision == revision)
        #expect(!presents([], read))
    }

    @Test(.disabled("waits on OB-7")) func storedIsNilWhenUnreadable() throws {
        let store = emptyStore()
        try store.writeData("preferences.json", Data("not json".utf8))
        #expect(OnboardingLaunch.stored(in: store) == nil)
    }
}
