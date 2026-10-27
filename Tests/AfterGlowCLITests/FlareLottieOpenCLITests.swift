// FlareLottieOpenCLITests.swift (lottie-open LO-3h, docs/blueprints/flare/features/lottie-open.md): the afterglow
// CLI opens a Lottie .json as an untitled Flare animation. `flare open` reads it and names its layers, a command run
// on it writes a .flare and leaves the JSON's bytes as they were, `--in-place` and an MCP save with no path refuse
// rather than write a .flare over the JSON, a script's Lottie output is named .json (the extension Flare opens, not
// the format id) and opens again, and a file that isn't Lottie is refused. The bounce fixture is FlareModelTests'
// hand-written one. In process, on a FakeIO; runs on Linux and macOS.
import AfterGlowCLICore
import FlareModel
import Foundation
import SuiteKernel
import Testing

@Suite struct FlareLottieOpenCLITests {
    static func bounce() throws -> Data {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FlareModelTests/Fixtures/Lottie/bounce.lottie.json")
        return try Data(contentsOf: file)
    }

    @Test func openPrintsTheLottieAsAnUntitledAnimation() throws {
        let io = FakeIO(files: ["bounce.json": try Self.bounce()])
        let code = CLI.run(["flare", "open", "bounce.json"], io: io)
        #expect(code == 0, "open exited \(code): \(io.stderr)")
        let printed = try JSONValue(json: Data((io.stdout.first ?? "").utf8))
        guard case .object(let fields) = printed, case .object(let summary)? = fields["summary"],
              case .array(let scenes)? = summary["scenes"], case .object(let scene)? = scenes.first else {
            Issue.record("no scene in \(io.stdout)")
            return
        }
        #expect(summary["name"] == .null, "a Lottie opens untitled")
        #expect(scene["layers"] == .number(2), "Ball and Floor")
    }

    @Test func aCommandOnTheJSONWritesAFlareAndLeavesTheJSON() throws {
        let input = try Self.bounce()
        let io = FakeIO(files: ["bounce.json": input])
        let code = CLI.run(["flare", "animate.go-to-end", "--in", "bounce.json", "--out", "bounce.flare"], io: io)
        #expect(code == 0, "the command exited \(code): \(io.stderr)")
        #expect(io.files["bounce.json"] == input, "the JSON was written")
        let saved = try #require(io.files["bounce.flare"], "no .flare written")
        #expect(throws: Never.self) { _ = try FlareHeadless.open(saved, name: "bounce.flare") }
        #expect(FlareHeadless.openExtensions.first == "flare", "Flare saves its own format, never Lottie")
    }

    @Test func aFileThatIsNotLottieIsRefused() {
        let io = FakeIO(files: ["settings.json": Data(#"{"a":1}"#.utf8)])
        let code = CLI.run(["flare", "open", "settings.json"], io: io)
        #expect(code != 0)
        #expect(io.stderr.joined().contains("isn't a Lottie file"), "\(io.stderr)")
    }

    @Test func inPlaceOnTheJSONIsRefusedAndLeavesIt() throws {
        let input = try Self.bounce()
        let io = FakeIO(files: ["copy.json": input])
        let code = CLI.run(["flare", "animate.go-to-end", "--in", "copy.json", "--in-place"], io: io)
        #expect(code == CLI.Exit.usage, "in-place on a Lottie exited \(code)")
        #expect(io.files["copy.json"] == input, "a .flare was written over the JSON")
        #expect(io.stderr.joined().contains("--out"), "\(io.stderr)")
    }

    @Test func anMCPSaveWithNoPathNeverWritesTheJSON() throws {
        let input = try Self.bounce()
        let io = FakeIO(files: ["/tmp/mcp/bounce.json": input])
        var sessions = MCPSessions(MCPOptions(apps: Apps.all, roots: ["/tmp/mcp"]), io: io)
        let opened = sessions.call(.open(app: "flare"), .object(["path": .string("/tmp/mcp/bounce.json")]), now: 0)
        guard case .object(let fields) = opened.structured, let doc = fields["doc"] else {
            Issue.record("open failed: \(opened.text)")
            return
        }
        let saved = sessions.call(.save, .object(["doc": doc, "force": .bool(true)]), now: 0)
        #expect(saved.isError, "save wrote with no path: \(saved.text)")
        #expect(io.files["/tmp/mcp/bounce.json"] == input, "a .flare was written over the JSON")
    }

    @Test func aScriptsLottieOutputIsNamedJSONAndOpensAgain() throws {
        let script = #"{"version":1,"app":"flare","inputs":["input/*.json"],"steps":[],"output":{"dir":"out","name":"{stem}-copy","format":"lottie"}}"#
        let io = FakeIO(files: ["job.jobs.json": Data(script.utf8), "input/bounce.json": try Self.bounce()])
        let code = CLI.run(["run", "job.jobs.json"], io: io)
        #expect(code == 0, "run exited \(code): \(io.stderr) \(io.stdout)")
        #expect(io.files["out/bounce-copy.lottie"] == nil, "a Lottie JSON was named .lottie, dotLottie's zip extension")
        #expect(io.files["out/bounce-copy.json"] != nil, "\(io.files.keys.sorted())")
        #expect(CLI.run(["flare", "open", "out/bounce-copy.json"], io: io) == 0, "the output doesn't open: \(io.stderr)")
    }
}
