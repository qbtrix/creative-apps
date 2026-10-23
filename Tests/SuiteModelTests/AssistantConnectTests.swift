// AssistantConnectTests.swift (cli-bundle CB-1, written first; CB-4 turns them on): the command quotes the bundled
// CLI's path, the JSON block is the stdio server an MCP client reads, and the install plan links only where nothing
// is, says when our link is already there and refuses any other file. Linux-safe.
import Foundation
import SuiteModel
import Testing

@Suite struct AssistantConnectTests {
    static let bundle = "/Users/tester/My Apps/AfterGlow.app"
    static let cli = bundle + "/Contents/Helpers/afterglow"
    static let home = "/Users/tester"

    @Test func cliPathIsInTheHelpers() {
        #expect(BundleLayout.cliPath == "Contents/Helpers/afterglow")
    }

    @Test func pathWithSpaceIsQuoted() {
        #expect(AssistantConnect.command(bundle: Self.bundle) == "\"\(Self.cli)\" mcp")
    }

    @Test func configParsesAndNamesTheServer() throws {
        let data = Data(AssistantConnect.configJSON(bundle: Self.bundle).utf8)
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let servers = try #require(root["mcpServers"] as? [String: Any])
        let server = try #require(servers["afterglow"] as? [String: Any])
        #expect(server["command"] as? String == Self.cli)
        #expect(server["args"] as? [String] == ["mcp"])
    }

    @Test func nothingThereIsLinked() {
        let plan = AssistantConnect.installPlan(home: Self.home, bundle: Self.bundle) { _ in nil }
        #expect(plan == .link(at: Self.home + "/.local/bin/afterglow", to: Self.cli))
    }

    @Test func ourLinkIsAlreadyLinked() {
        let plan = AssistantConnect.installPlan(home: Self.home, bundle: Self.bundle) { _ in Self.cli }
        #expect(plan == .alreadyLinked(Self.home + "/.local/bin/afterglow"))
    }

    @Test func neverOverwritesForeignFile() {
        for other in ["/opt/homebrew/bin/afterglow", "", "/Users/tester/old/AfterGlow.app/Contents/Helpers/afterglow"] {
            let plan = AssistantConnect.installPlan(home: Self.home, bundle: Self.bundle) { _ in other }
            guard case .refuse(let reason) = plan else { Issue.record("\(other) is replaced: \(plan)"); continue }
            #expect(!reason.isEmpty)
        }
    }

    @Test func quotesAndBackslashesAreEscaped() throws {
        let bundle = #"/Users/tester/a "b" \c/AfterGlow.app"#
        #expect(AssistantConnect.command(bundle: bundle) == #""/Users/tester/a \"b\" \\c/AfterGlow.app/Contents/Helpers/afterglow" mcp"#)
        let data = Data(AssistantConnect.configJSON(bundle: bundle).utf8)
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let server = try #require((root["mcpServers"] as? [String: Any])?["afterglow"] as? [String: Any])
        #expect(server["command"] as? String == bundle + "/Contents/Helpers/afterglow")
    }

    @Test func aTrailingSlashOnHomeMakesOnePath() {
        let plan = AssistantConnect.installPlan(home: Self.home + "/", bundle: Self.bundle) { _ in nil }
        #expect(plan == .link(at: Self.home + "/.local/bin/afterglow", to: Self.cli))
    }
}
