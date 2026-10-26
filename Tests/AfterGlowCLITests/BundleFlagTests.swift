// BundleFlagTests.swift (cli-bundle CB-z, drift #5643, written first): `afterglow suite <command> --bundle
// <AfterGlow.app>` names the bundle the assistant commands answer for, so a CLI run from outside the bundle (this
// test process) still answers help.connect-assistant; without the flag it stays unavailable with the why-not that
// names --bundle. `--bundle` is a value flag of the suite's command form only. Linux-safe; files live in a FakeIO.
@testable import AfterGlowCLICore
import Foundation
import SuiteModel
import Testing

@Suite struct BundleFlagTests {
    static let bundle = "/Applications/AfterGlow.app"
    static let launcher = Data(#"{"app":"launcher"}"#.utf8)
    static let connect = ["suite", "help.connect-assistant", "--in", "in.suitehelp", "--out", "o.suitehelp"]

    /// The parse of `arguments` against the CLI's registry, or the refusal's message.
    static func parse(_ arguments: [String]) -> Result<Invocation, Refusal> {
        do throws(Refusal) { return .success(try Arguments.parse(arguments, apps: CLI.registry)) } catch { return .failure(error) }
    }

    /// The refusal's code and message, nil when `arguments` parse.
    static func refusal(_ arguments: [String]) -> (Int32, String)? {
        guard case .failure(let refusal) = parse(arguments) else { return nil }
        return (refusal.code, refusal.message)
    }

    /// Opens the launcher's Help document as the app the parse of `arguments` chose and answers help.connect-assistant.
    static func answer(_ arguments: [String]) throws -> JSONValue {
        guard case .success(.command(let app, let step, _, _, _)) = parse(arguments) else { Issue.record("not a command"); return .null }
        var session = try app.session(open: launcher, name: "in.suitehelp")
        return try session.run(step).result
    }

    @Test func theFlagParsesAndReachesTheProvider() throws {
        let answer = try Self.answer(Self.connect + ["--bundle", Self.bundle])
        #expect(answer == .object(["command": .string(AssistantConnect.command(bundle: Self.bundle)),
                                   "json": .string(AssistantConnect.configJSON(bundle: Self.bundle))]))
    }

    @Test func theFlagIsRefusedTwiceOrWithoutAValue() {
        let twice = Self.refusal(Self.connect + ["--bundle", Self.bundle, "--bundle", "/tmp/Other.app"])
        #expect(twice?.0 == CLI.Exit.usage && twice?.1.contains("--bundle is given twice") == true)
        let bare = Self.refusal(Self.connect + ["--bundle"])
        #expect(bare?.0 == CLI.Exit.usage && bare?.1.contains("--bundle needs a value") == true)
    }

    @Test func otherAppsRefuseTheFlag() {
        let photo = Self.refusal(["photo", "list-commands"]) == nil
        #expect(photo)
        let refused = Self.refusal(["photo", "edit.copy", "--in", "a.png", "--out", "b.png", "--bundle", Self.bundle])
        #expect(refused?.0 == CLI.Exit.usage && refused?.1.contains("--bundle") == true)
    }

    @Test func theRunAnswersForTheNamedBundle() throws {
        let io = FakeIO(files: ["in.suitehelp": Self.launcher])
        let code = CLI.run(Self.connect + ["--bundle", Self.bundle], io: io)
        #expect(code == CLI.Exit.ok, "\(io.stderr)")
        let saved = try JSONValue(json: io.files["o.suitehelp"] ?? Data())
        guard case .object(let fields) = saved, case .object(let answer)? = fields["answer"] else { Issue.record("no answer"); return }
        #expect(answer["command"] == .string(AssistantConnect.command(bundle: Self.bundle)))
    }

    @Test func withoutTheFlagConnectStaysUnavailable() {
        let io = FakeIO(files: ["in.suitehelp": Self.launcher])
        #expect(CLI.run(Self.connect, io: io) == CLI.Exit.unavailable)
        #expect((io.stdout + io.stderr).joined().contains("pass --bundle <path to AfterGlow.app>"))
    }

    @Test func usageShowsTheFlag() {
        #expect(Arguments.usage.contains("afterglow suite <command> --in <file> (--out <file> | --in-place) --bundle <AfterGlow.app>"))
    }
}
