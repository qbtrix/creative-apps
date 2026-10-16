// ValuesSettingsTests.swift: preferences clamp the autosave interval,
// versions parse and compare, the update feed picks the newest offer above
// the running version, and onboarding and animation values keep their data.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel
import Testing

@Suite struct ValuesSettingsTests {
    @Test func autosaveClampsToTenThroughSixHundred() {
        #expect(SuitePreferences().autosaveSeconds == 30)
        #expect(SuitePreferences(autosaveSeconds: 2).autosaveSeconds == 10)
        #expect(SuitePreferences(autosaveSeconds: 10).autosaveSeconds == 10)
        #expect(SuitePreferences(autosaveSeconds: 600).autosaveSeconds == 600)
        #expect(SuitePreferences(autosaveSeconds: 601).autosaveSeconds == 600)
        #expect(SuitePreferences(autosaveSeconds: -5).autosaveSeconds == 10)
    }

    @Test func preferenceDefaults() {
        let p = SuitePreferences()
        #expect(p.revision == 0)
        #expect(p.units == .points)
        #expect(p.checkForUpdates)
        #expect(p.onboardingDoneVersion == nil)
        #expect(p.homeOrder == SuiteApp.apps)
        #expect(p.perApp.isEmpty)
        #expect(LengthUnit.allCases.count == 5)
    }

    @Test func preferencesSurviveJSON() throws {
        let p = SuitePreferences(revision: 3, units: .millimeters, autosaveSeconds: 120, checkForUpdates: false,
                                 onboardingDoneVersion: 1, homeOrder: [.halo, .flare],
                                 perApp: ["flare": ["onionSkin": "on"]])
        let back = try JSONDecoder().decode(SuitePreferences.self, from: JSONEncoder().encode(p))
        #expect(back == p)
    }

    @Test func versionParses() {
        #expect(SuiteVersion("1.2") == SuiteVersion(1, 2, 0))
        #expect(SuiteVersion("3") == SuiteVersion(3, 0, 0))
        #expect(SuiteVersion("1.2.3") == SuiteVersion(1, 2, 3))
        #expect(SuiteVersion("1.x") == nil)
        #expect(SuiteVersion("") == nil)
        #expect(SuiteVersion("1.2.3.4") == nil)
    }

    @Test func versionCompares() {
        #expect(SuiteVersion(1, 9, 9) < SuiteVersion(1, 10, 0))
        #expect(SuiteVersion(1, 2, 0) < SuiteVersion(1, 2, 1))
        #expect(!(SuiteVersion(2, 0, 0) < SuiteVersion(1, 9, 9)))
        #expect((SuiteVersion("1.10") ?? SuiteVersion(0, 0, 0)) > SuiteVersion(1, 9, 9))
    }

    static let feed = """
    [
      {"version": {"major": 1, "minor": 1, "patch": 0}, "notes": "Fixes.", "url": "https://example.org/1.1.0.zip",
       "byteCount": 100, "signature": "c2ln", "minimumSystem": "26.0"},
      {"version": {"major": 1, "minor": 3, "patch": 0}, "notes": "Layers.", "url": "https://example.org/1.3.0.zip",
       "byteCount": 300, "signature": "c2ln", "minimumSystem": "26.0"},
      {"version": {"major": 1, "minor": 2, "patch": 0}, "notes": "Brushes.", "url": "https://example.org/1.2.0.zip",
       "byteCount": 200, "signature": "c2ln", "minimumSystem": "26.0"}
    ]
    """

    @Test func feedPicksTheNewestAboveCurrent() throws {
        let data = Data(Self.feed.utf8)
        let offer = try UpdateFeed.newest(in: data, above: SuiteVersion(1, 1, 0))
        #expect(offer?.version == SuiteVersion(1, 3, 0))
        #expect(offer?.notes == "Layers.")
        #expect(offer?.url == "https://example.org/1.3.0.zip")
        #expect(offer?.byteCount == 300)
        #expect(offer?.minimumSystem == "26.0")
        #expect(try UpdateFeed.newest(in: data, above: SuiteVersion(1, 2, 5))?.version == SuiteVersion(1, 3, 0))
        #expect(try UpdateFeed.newest(in: data, above: SuiteVersion(1, 3, 0)) == nil)
        #expect(try UpdateFeed.newest(in: Data("[]".utf8), above: SuiteVersion(0, 0, 1)) == nil)
    }

    @Test func damagedFeedThrows() {
        #expect(throws: SuiteError.damaged(UpdateFeed.subject)) {
            try UpdateFeed.newest(in: Data("{\"not\": \"a list\"}".utf8), above: SuiteVersion(1, 0, 0))
        }
    }

    @Test func damagedFeedSaysUpdatesInPlainWords() {
        var message = ""
        do { _ = try UpdateFeed.newest(in: Data("not json".utf8), above: SuiteVersion(1, 0, 0)) } catch { message = error.message }
        #expect(message.contains("the list of available updates"))
        #expect(!message.lowercased().contains("feed"))
    }

    @Test func onboardingAndAnimationValues() throws {
        let page = OnboardingPage(id: "focus", title: "What do you make?", body: "Pick one.", choices: [.design, .motion])
        #expect(page.choices == [.design, .motion])
        #expect(OnboardingPage(id: "welcome", title: "Welcome", body: "Hi.").choices.isEmpty)
        #expect(OnboardingFocus.allCases.count == 5)
        let summary = AnimationSummary(name: "Bounce", width: 1080, height: 1920, framesPerSecond: 30,
                                       frameCount: 90, sceneNames: ["Intro", "Loop"])
        let back = try JSONDecoder().decode(AnimationSummary.self, from: JSONEncoder().encode(summary))
        #expect(back == summary)
    }
}
