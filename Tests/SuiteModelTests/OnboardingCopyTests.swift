// OnboardingCopyTests.swift: the welcome window's copy (onboarding packet,
// Screens and states; critic findings #2884, #2885, #3016, #3017). The focus
// page names the one way back (Help > Welcome to AfterGlow, Settings being out
// of the beta) and each focus chip names the apps it puts first; the start
// page carries the packet's title; a preset chip that asks for more keeps its
// ellipsis, a one-step one names the new document, and no help says "at once".
import SuiteModel
import Testing

@Suite(.timeLimit(.minutes(1))) struct OnboardingCopyTests {
    func page(_ id: String) -> OnboardingPage? { SuiteOnboarding().pages.first { $0.id == id } }
    func tile(_ app: SuiteApp) -> NewTile {
        NewTile(app: app, title: SuiteCreating.titles[app] ?? "", presets: SuiteCreating.presets[app] ?? [])
    }

    @Test func focusPagePointsToHelpNotSettings() throws {
        let focus = try #require(page("focus"))
        #expect(focus.body == "Each choice puts the apps it names first, here and on the home. Change it any time from Help > Welcome to AfterGlow.")
        #expect(!focus.body.contains("Settings"))
    }

    @Test func startPageHasThePacketTitle() throws {
        let start = try #require(page("start"))
        #expect(start.title == "Start with a sample or a new document")
        #expect(start.body == "Open a sample to see an app at work, or click a chip to start a new document. A chip ending in … asks for details first.")
        #expect(!start.body.contains("at once"))
    }

    @Test func presetChipsKeepTheEllipsisOfAPresetThatAsks() {
        let titles = SuiteApp.apps.flatMap { SuiteCreating.presets[$0] ?? [] }.map(SuiteOnboarding.presetTitle)
        #expect(titles == ["New 1080p 16:9 Animation", "New Square Animation", "New Vertical 9:16 Animation",
                           "New Blank Design", "New Image…", "Import Folder…", "New Composition…"])
        for preset in SuiteApp.apps.flatMap({ SuiteCreating.presets[$0] ?? [] }) {
            let asks = ["library.import", "photo.sheet", "halo.sheet"].contains(preset.id)
            #expect(SuiteOnboarding.asksForMore(preset) == asks, "\(preset.id)")
            #expect(SuiteOnboarding.presetTitle(preset).hasSuffix("…") == asks, "\(preset.id)")
        }
        #expect(!titles.contains("New Blank"))
    }

    @Test func presetTitleKeepsAnExistingVerb() {
        let preset = NewDocumentPreset(id: "x", app: .photo, title: "New Canvas", detail: "")
        #expect(SuiteOnboarding.presetTitle(preset) == "New Canvas")
        let other = NewDocumentPreset(id: "y", app: .launcher, title: "Blank", detail: "")
        #expect(SuiteOnboarding.presetTitle(other) == "New Blank Document")
        let asks = NewDocumentPreset(id: "z", app: .flare, title: "Custom Size…", detail: "")
        #expect(SuiteOnboarding.presetTitle(asks) == "Custom Size…")
    }

    @Test func presetHelpSaysWhatAClickDoesWithoutAtOnce() {
        #expect(SuiteOnboarding.presetsHelp(tile(.flare)) == "Creates a new Flare document and closes this window.")
        #expect(SuiteOnboarding.presetsHelp(tile(.library)) == "Opens Library, which asks for the details before it starts.")
        #expect(SuiteOnboarding.presetsHelp(tile(.halo)) == "Opens Halo, which asks for the details before it starts.")
        let mixed = NewTile(app: .photo, title: "New Image", presets: [
            NewDocumentPreset(id: "a", app: .photo, title: "Square", detail: ""),
            NewDocumentPreset(id: "b", app: .photo, title: "Custom…", detail: ""),
        ])
        #expect(SuiteOnboarding.presetsHelp(mixed) == "Creates a new Photo document; a chip ending in … asks for details first.")
        for app in SuiteApp.apps { #expect(!SuiteOnboarding.presetsHelp(tile(app)).contains("at once")) }
    }

    @Test func focusChipsNameTheAppsTheyPutFirst() {
        #expect(OnboardingFocus.allCases.map(SuiteOnboarding.focusTitle) == [
            "Animation: Flare, Halo", "Design", "Photos: Library, Photo", "Motion graphics: Halo, Flare", "Everything",
        ])
        for focus in OnboardingFocus.allCases {
            let first = FakeOnboarding.firstApps(for: focus)
            #expect(SuiteOnboarding.order(for: focus).starts(with: first), "\(focus)")
            if let lead = first.first {
                #expect(SuiteOnboarding.focusTitle(focus).contains(lead.displayName), "\(focus)")
            }
        }
        #expect(SuiteOnboarding.focusTitle(.animation) != SuiteOnboarding.focusTitle(.motion))
    }
}
