// AssistantConnectPanelTests.swift (cli-bundle CB-5): the Connect an AI Assistant sheet shows AssistantConnect's
// text for the running bundle, says why when there is none, disables each Copy that has nothing to copy, enables
// Install once a bundle is known (CB-6), and finds AfterGlow.app from the launcher's or a helper's own path. Linux-safe.
import SuiteModel
import Testing

@Suite struct AssistantConnectPanelTests {
    static let bundle = "/Users/tester/My Apps/AfterGlow.app"

    @Test func readsAssistantConnectForTheBundle() {
        let panel = AssistantConnectPanel(bundle: Self.bundle)
        #expect(panel.command == AssistantConnect.command(bundle: Self.bundle))
        #expect(panel.configJSON == AssistantConnect.configJSON(bundle: Self.bundle))
    }

    @Test func textCopiesAndShows() {
        let panel = AssistantConnectPanel(command: "\"/A/AfterGlow.app/Contents/Helpers/afterglow\" mcp", configJSON: "{}")
        #expect(panel.shownCommand == panel.command)
        #expect(panel.shownConfig == "{}")
        #expect(panel.copyCommandUnavailable == nil)
        #expect(panel.copyConfigUnavailable == nil)
    }

    @Test func emptyTextIsExplainedAndCopyDisabled() {
        let panel = AssistantConnectPanel(command: "", configJSON: "")
        #expect(panel.shownCommand == AssistantConnectPanel.notBuilt)
        #expect(panel.shownConfig == AssistantConnectPanel.notBuilt)
        #expect(panel.copyCommandUnavailable == AssistantConnectPanel.nothingToCopy)
        #expect(panel.copyConfigUnavailable == AssistantConnectPanel.nothingToCopy)
        let onlyConfig = AssistantConnectPanel(command: "", configJSON: "{}")
        #expect(onlyConfig.copyCommandUnavailable != nil && onlyConfig.copyConfigUnavailable == nil)
    }

    @Test func installRunsWhenABundleIsKnown() {
        #expect(AssistantConnectPanel(bundle: Self.bundle).installUnavailable == nil)
        #expect(AssistantConnectPanel(command: "x", configJSON: "y").installUnavailable == AssistantConnectPanel.installNeedsBundle)
    }

    @Test func findsTheBundleFromItsOwnOrAHelpersPath() {
        #expect(AssistantConnectPanel.bundle(containing: Self.bundle) == Self.bundle)
        #expect(AssistantConnectPanel.bundle(containing: Self.bundle + "/Contents/Helpers/Photo.app") == Self.bundle)
        #expect(AssistantConnectPanel.bundle(containing: "/Users/tester/dev/.build/debug/Photo.app") == nil)
        #expect(AssistantConnectPanel.bundle(containing: "/Applications/NotAfterGlow.app") == nil)
    }
}
