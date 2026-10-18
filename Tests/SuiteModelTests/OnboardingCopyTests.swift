// OnboardingCopyTests.swift: the welcome window's copy (onboarding packet,
// Screens and states; critic findings #2884, #2885). The focus page names the
// one way back (Help > Welcome to AfterGlow, Settings being out of the beta),
// the start page carries the packet's title, and every preset chip says "New"
// or "Import" with no ellipsis, since one click creates the document.
import SuiteModel
import Testing

@Suite(.timeLimit(.minutes(1))) struct OnboardingCopyTests {
    func page(_ id: String) -> OnboardingPage? { SuiteOnboarding().pages.first { $0.id == id } }

    @Test func focusPagePointsToHelpNotSettings() throws {
        let focus = try #require(page("focus"))
        #expect(focus.body == "AfterGlow puts those apps first. Change it any time from Help > Welcome to AfterGlow.")
        #expect(!focus.body.contains("Settings"))
    }

    @Test func startPageHasThePacketTitle() throws {
        let start = try #require(page("start"))
        #expect(start.title == "Start with a sample or a new document")
        #expect(start.body == "Open a sample to see an app at work, or click a New chip to start a document at once.")
    }

    @Test func presetChipsSayNewWithNoEllipsis() {
        let titles = SuiteApp.apps.flatMap { SuiteCreating.presets[$0] ?? [] }.map(SuiteOnboarding.presetTitle)
        #expect(titles == ["New 1080p 16:9", "New Square", "New Vertical 9:16", "New Blank", "New Image",
                           "Import Folder", "New Composition"])
        for title in titles {
            #expect(!title.hasSuffix("…") && (title.hasPrefix("New ") || title.hasPrefix("Import ")), "\(title)")
        }
    }

    @Test func presetTitleKeepsAnExistingVerb() {
        let preset = NewDocumentPreset(id: "x", app: .photo, title: "New Canvas……", detail: "")
        #expect(SuiteOnboarding.presetTitle(preset) == "New Canvas")
    }
}
