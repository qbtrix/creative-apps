// MCPConfigTests.swift (cli-bundle CB-2, written first; CB-4 turns the answers on): `afterglow suite` lists
// help.connect-assistant and help.install-cli with their schemas, finds AfterGlow.app from `--bundle` or its own
// path inside the bundle, and answers the two commands with AssistantConnect's text and plan. Linux-safe; files
// live in a FakeIO.
import AfterGlowCLICore
import Foundation
import SuiteModel
import Testing

@Suite struct MCPConfigTests {
    static let bundle = "/Applications/My Apps/AfterGlow.app"
    static let cli = bundle + "/Contents/Helpers/afterglow"

    /// Runs `afterglow <arguments>` over `io` and reads back its exit code and its one stdout object.
    static func run(_ arguments: [String], _ io: FakeIO) throws -> (Int32, [String: JSONValue]) {
        let code = CLI.run(arguments, io: io)
        guard case .object(let fields) = try JSONValue(json: Data((io.stdout.last ?? "").utf8)) else { return (code, [:]) }
        return (code, fields)
    }

    @Test func specsListWithTheirSchemas() throws {
        let io = FakeIO()
        let (code, listed) = try Self.run(["suite", "list-commands"], io)
        #expect(code == 0, "\(io.stderr)")
        guard case .array(let commands)? = listed["commands"] else { Issue.record("no commands"); return }
        let ids = commands.compactMap { command -> String? in
            if case .object(let fields) = command, case .string(let id)? = fields["id"] { id } else { nil }
        }
        #expect(ids.contains("help.connect-assistant") && ids.contains("help.install-cli"))
        for id in ["help.connect-assistant", "help.install-cli"] {
            let (code, described) = try Self.run(["suite", "describe", id], io)
            #expect(code == 0, "\(io.stderr)")
            guard case .object(let command)? = described["command"], case .object(let result)? = command["result"],
                  case .object(let properties)? = result["properties"] else { Issue.record("\(id) has no result schema"); continue }
            #expect(command["kind"] == .string(id == "help.connect-assistant" ? "query" : "file"), "install writes outside the document")
            #expect(command["undoable"] == .bool(false), "\(id) is not an undo step")
            let expected: Set<String> = id == "help.connect-assistant" ? ["command", "json"] : ["plan", "at", "to", "reason", "linked"]
            #expect(Set(properties.keys) == expected)
        }
        let (_, install) = try Self.run(["suite", "describe", "help.install-cli"], io)
        guard case .object(let command)? = install["command"], case .object(let params)? = command["params"],
              case .object(let properties)? = params["properties"] else { Issue.record("install-cli has no params"); return }
        #expect(properties["confirm"] != nil)
    }

    @Test func bundleFlagWins() {
        #expect(MCPConfig.bundle(flag: Self.bundle, executable: "/usr/local/bin/afterglow") == Self.bundle)
        #expect(MCPConfig.bundle(flag: Self.bundle + "/", executable: "") == Self.bundle)
    }

    @Test func ownPathWalksUpToTheApp() {
        #expect(MCPConfig.bundle(flag: nil, executable: Self.cli) == Self.bundle)
        #expect(MCPConfig.bundle(flag: nil, executable: "/src/creative-apps/.build/release/afterglow") == nil)
        #expect(MCPConfig.bundle(flag: nil, executable: "afterglow") == nil)
        #expect(MCPConfig.bundle(flag: nil, executable: "/Contents/Helpers/afterglow") == nil, "no app above the helper")
    }

    @Test func outsideABundleConnectIsUnavailable() throws {
        let io = FakeIO(files: ["in.suitehelp": Data(#"{"app":"launcher"}"#.utf8)])
        let (code, _) = try Self.run(["suite", "help.connect-assistant", "--in", "in.suitehelp", "--out", "o.suitehelp"], io)
        #expect(code == CLI.Exit.unavailable)
        #expect(io.stdout.joined().contains("--bundle") || io.stderr.joined().contains("--bundle"), "the why-not names --bundle")
    }

    @Test func noBundleAnswersNothing() {
        let config = MCPConfig(bundle: nil, home: "/Users/tester")
        #expect(config.connectAssistant() == .null)
        #expect(config.installCLI(confirm: false) { _ in nil } == .null)
    }

    @Test(.disabled("waits on CB-4")) func connectAnswersAssistantConnectsText() {
        let config = MCPConfig(bundle: Self.bundle, home: "/Users/tester")
        #expect(config.connectAssistant() == .object(["command": .string("\"\(Self.cli)\" mcp"),
                                                      "json": .string(AssistantConnect.configJSON(bundle: Self.bundle))]))
    }

    @Test(.disabled("waits on CB-4")) func installWithoutConfirmReturnsThePlanOnly() {
        let config = MCPConfig(bundle: Self.bundle, home: "/Users/tester")
        var asked = [String]()
        let plan = config.installCLI(confirm: false) { asked.append($0); return nil }
        #expect(plan == .object(["plan": .string("link"), "at": .string("/Users/tester/.local/bin/afterglow"),
                                 "to": .string(Self.cli), "linked": .bool(false)]))
        #expect(asked == ["/Users/tester/.local/bin/afterglow"])
    }

    @Test(.disabled("waits on CB-4")) func aForeignFileIsRefusedWithItsReason() {
        let config = MCPConfig(bundle: Self.bundle, home: "/Users/tester")
        guard case .object(let plan) = config.installCLI(confirm: true, existing: { _ in "/opt/homebrew/bin/afterglow" }) else {
            Issue.record("no plan"); return
        }
        #expect(plan["plan"] == .string("refuse"))
        #expect(plan["linked"] == .bool(false), "confirm never writes over a foreign file")
        if case .string(let reason)? = plan["reason"] { #expect(!reason.isEmpty) } else { Issue.record("no reason") }
    }
}
