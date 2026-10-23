// AIAccessPromptTests.swift (afterglow-mcp MC-12): the approval sheet's,
// chip's and list's copy, and the -AIAccessDemoRequest launch hook.
import SuiteModel
import Testing

@Suite struct AIAccessPromptTests {
    @Test func demoClientIsTheNameAfterTheFlag() {
        #expect(AIAccessPrompt.demoClient(in: ["app", "-AIAccessDemoRequest", "Test Client"]) == "Test Client")
        #expect(AIAccessPrompt.demoClient(in: ["app", "-AIAccessDemoRequest", "Test Client", "-Fixture"]) == "Test Client")
    }

    @Test func demoClientIsNilWithoutAName() {
        #expect(AIAccessPrompt.demoClient(in: ["app"]) == nil)
        #expect(AIAccessPrompt.demoClient(in: ["app", "-AIAccessDemoRequest"]) == nil)
        #expect(AIAccessPrompt.demoClient(in: ["app", "-AIAccessDemoRequest", " "]) == nil)
        #expect(AIAccessPrompt.demoClient(in: ["app", "-AIAccessDemoRequest", "-Fixture"]) == nil)
    }

    @Test func sheetNamesClientAppAndCommand() {
        let bare = AIAccessRequest(client: "Test Client", app: "AfterGlow")
        #expect(AIAccessPrompt.title(bare) == "Allow the AI assistant “Test Client” to work in AfterGlow?")
        #expect(!AIAccessPrompt.message(bare).contains("asked to run"))
        let asked = AIAccessRequest(client: "Test Client", app: "Photo", command: "photo.crop")
        #expect(AIAccessPrompt.message(asked).hasSuffix("It asked to run “photo.crop”."))
        #expect(!AIAccessPrompt.message(AIAccessRequest(client: "c", app: "a", command: "")).contains("asked to run"))
    }

    @Test func messageScopesToTheDocumentOrTheApp() {
        let home = AIAccessPrompt.message(AIAccessRequest(client: "Test Client", app: "AfterGlow"))
        #expect(!home.contains("the open document") && home.contains("your documents in AfterGlow"))
        let named = AIAccessPrompt.message(AIAccessRequest(client: "Test Client", app: "Design", document: "Logo.design"))
        #expect(named.contains("“Logo.design”") && !named.contains("your documents"))
        #expect(AIAccessPrompt.message(AIAccessRequest(client: "c", app: "Photo", document: "")).contains("your documents in Photo"))
    }

    @Test func messageSaysHowToStop() {
        let message = AIAccessPrompt.message(AIAccessRequest(client: "Test Client", app: "AfterGlow"))
        #expect(message.contains("click \(AIAccessPrompt.stop)") && message.contains("Window > \(AIAccessPrompt.windowTitle)"))
    }

    @Test func choiceHelpSaysEachAllowsScope() {
        let help = AIAccessPrompt.choiceHelp(AIAccessRequest(client: "Test Client", app: "AfterGlow"))
        #expect(help == "Allow Once lasts until “Test Client” disconnects. Always Allow remembers “Test Client” for AfterGlow.")
    }

    @Test func chipAndStatusText() {
        #expect(AIAccessPrompt.chip(client: "Test Client") == "Controlled by Test Client")
        #expect(AIAccessPrompt.status(.allowOnce) == "Allowed once")
        #expect(AIAccessPrompt.status(.alwaysForClient) == "Always allowed")
        #expect(AIAccessPrompt.status(.deny) == "Denied")
        #expect(AIAccessPrompt.menuTitle == "AI Access…")
    }
}
