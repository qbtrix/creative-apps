// BundleLayoutTests.swift: where AfterGlow.app puts each executable and
// framework, and the run path each one needs to find the frameworks.
import SuiteModel
import Testing

@Suite struct BundleLayoutTests {
    @Test func flareHelperPaths() {
        #expect(BundleLayout.executablePath(ofApp: "Flare") == "Contents/Helpers/Flare.app/Contents/MacOS/Flare")
        #expect(BundleLayout.runPath(ofApp: "Flare") == "@executable_path/../../../../Frameworks")
    }

    @Test func launcherPaths() {
        #expect(BundleLayout.executablePath(ofApp: nil) == "Contents/MacOS/AfterGlow")
        #expect(BundleLayout.runPath(ofApp: nil) == "@executable_path/../Frameworks")
    }

    @Test func everyAppIsAHelper() {
        #expect(BundleLayout.apps == ["Flare", "Design", "Photo", "Library", "Halo"])
        for app in BundleLayout.apps {
            #expect(BundleLayout.executablePath(ofApp: app) == "Contents/Helpers/\(app).app/Contents/MacOS/\(app)")
        }
    }

    @Test func fourFrameworksInOrder() {
        #expect(BundleLayout.frameworks == ["SuiteUI", "SuiteModel", "SuiteShell", "CreativeEngines"])
    }
}
