// RenderingPreferenceLiveTests.swift: CH-7's checks of the live store. Each
// test opens a scratch defaults domain so it never touches the suite's real
// one. A write is read back by a second instance and by a new instance after
// the first is gone (a relaunch), observers hear each change once and a repeat
// not at all, and device loss falls back only under Automatic. macOS only.
import Combine
import Foundation
import Testing

@testable import SuiteUI

@MainActor @Suite struct RenderingPreferenceLiveTests {
    private func scratchDomain() -> String {
        "org.creativesuite.tests.rendering.\(UUID().uuidString)"
    }

    private func forget(_ domain: String) {
        UserDefaults.standard.removePersistentDomain(forName: domain)
    }

    @Test func aWriteIsReadBackByASecondInstanceAndAfterARelaunch() throws {
        let domain = scratchDomain()
        defer { forget(domain) }
        let second = RenderingPreference(suiteName: domain)
        #expect(second.choice == .automatic)

        do {
            let first = RenderingPreference(suiteName: domain)
            first.set(.cpu)
            #expect(first.choice == .cpu)
            #expect(second.choice == .cpu)
        }

        let relaunched = RenderingPreference(suiteName: domain)
        #expect(relaunched.choice == .cpu)

        let raw = try #require(UserDefaults(suiteName: domain))
        #expect(raw.string(forKey: RenderingPreference.key) == "cpu")
        raw.set("gpu", forKey: RenderingPreference.key)
        #expect(relaunched.choice == .gpu)
        raw.set("metal", forKey: RenderingPreference.key)
        #expect(relaunched.choice == .automatic)
    }

    @Test func theAppsUseTheSuitesOneSharedDomain() {
        #expect(RenderingPreference.suiteName == "org.creativesuite.shared")
        #expect(RenderingPreference.key == "suite.rendering")
    }

    @Test func observeFiresOncePerChangeAndNotOnARepeat() {
        let domain = scratchDomain()
        defer { forget(domain) }
        let writer = RenderingPreference(suiteName: domain)
        let reader = RenderingPreference(suiteName: domain)
        let heardByWriter = HeardLiveChoices()
        let heardByReader = HeardLiveChoices()
        let writerToken = writer.observe { heardByWriter.choices.append($0) }
        let readerToken = reader.observe { heardByReader.choices.append($0) }

        writer.set(.gpu)
        writer.set(.gpu)
        writer.set(.cpu)
        writer.set(.cpu)
        writer.set(.automatic)

        #expect(writer.writes == [.gpu, .gpu, .cpu, .cpu, .automatic])
        #expect(heardByWriter.choices == [.gpu, .cpu, .automatic])
        #expect(heardByReader.choices == [.gpu, .cpu, .automatic])
        writerToken.cancel()
        readerToken.cancel()
    }

    @Test func deviceLossFallsBackOnlyUnderAutomatic() {
        let domain = scratchDomain()
        defer { forget(domain) }
        let preference = RenderingPreference(suiteName: domain)
        #expect(preference.status == RenderingStatus(active: "GPU", note: nil))

        preference.loseDevice()
        #expect(preference.status == RenderingStatus(active: "CPU", note: "Drawing on CPU: Metal stopped"))

        preference.set(.gpu)
        #expect(preference.status == RenderingStatus(active: "GPU", note: "Metal stopped"))

        preference.set(.cpu)
        #expect(preference.status == RenderingStatus(active: "CPU", note: nil))

        let other = RenderingPreference(suiteName: domain)
        other.set(.automatic)
        #expect(other.status == RenderingStatus(active: "GPU", note: nil))
    }
}

@MainActor private final class HeardLiveChoices {
    var choices: [RenderingChoice] = []
}
