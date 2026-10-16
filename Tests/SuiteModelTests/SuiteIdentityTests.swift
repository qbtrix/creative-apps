// SuiteIdentityTests.swift: the suite's id strings and the app list must not
// drift; bundle plists, the switch menu and every placeholder read them.
import SuiteModel
import Testing

@Suite struct SuiteIdentityTests {
    @Test func prefixAndLauncherID() {
        #expect(SuiteIdentity.prefix == "org.creativesuite")
        #expect(SuiteIdentity.launcherBundleID == "org.creativesuite.afterglow")
    }

    @Test func notConnectedSaysWhatIsMissingInPlainWords() {
        #expect(SuiteIdentity.notConnected("home") == "The Home window isn't available yet.")
        #expect(SuiteIdentity.notConnected("switching") == "Switching between apps isn't available yet.")
        #expect(SuiteIdentity.notConnected("no-such-feature") == "This isn't available yet.")
    }

    @Test func appsInSwitchOrder() {
        #expect(SuiteApp.allCases == [.launcher, .flare, .design, .photo, .library, .halo])
    }
}
