// SuiteIdentityTests.swift: the suite's id strings and the app list must not
// drift; bundle plists, the switch menu and every placeholder read them.
import SuiteModel
import Testing

@Suite struct SuiteIdentityTests {
    @Test func prefixAndLauncherID() {
        #expect(SuiteIdentity.prefix == "org.creativesuite")
        #expect(SuiteIdentity.launcherBundleID == "org.creativesuite.afterglow")
    }

    @Test func notConnectedNamesTheFeature() {
        #expect(SuiteIdentity.notConnected("home") == "Not connected yet (home).")
    }

    @Test func appsInSwitchOrder() {
        #expect(SuiteApp.allCases == [.launcher, .flare, .design, .photo, .library, .halo])
    }
}
