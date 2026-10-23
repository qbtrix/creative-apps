// FlareLottieOpenCLITests.swift (lottie-open LO-3h, docs/blueprints/flare/features/lottie-open.md): the afterglow
// CLI opens a Lottie .json as an untitled Flare animation. `flare open` reads it and names its layers, a command run
// on it writes a .flare and leaves the JSON's bytes as they were, and a file that isn't Lottie is refused. The bounce
// fixture is FlareModelTests' hand-written one. In process, on a FakeIO; runs on Linux and macOS.
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
}
