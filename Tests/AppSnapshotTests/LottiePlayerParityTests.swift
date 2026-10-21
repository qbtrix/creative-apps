// LottiePlayerParityTests.swift (lottie-player-check LP-2, #3792): a Lottie Flare writes must play in a reference
// player as the stage draws it. Each fixture under Fixtures/Lottie/ opens and exports to Lottie through
// `FlareHeadless`; LP-1's oracle (ThorVG behind `.build/lottie-oracle/render <file.json> <frame> <w> <h>`, raw RGBA
// over white on stdout) renders frames 0, the middle and the last, `StageRasterizer` renders the same frames, and the
// two agree when at most 2% of pixels differ by more than 8 levels (LP-3's `FrameParity`, tested on Linux). The loop
// rule: the oracle's last frame (`op - 1`) is not frame 0 again, so the loop doesn't stutter. Colour-key and trim
// (LP-5) are listed but skip by name until the stage-matches-export fix lands.
// A bounce whose keys land one frame late must fail the compare. The whole suite skips, with that reason, until
// `scripts/lottie-oracle/build` has made the oracle. Exports and frames land in .build/lottie-oracle/parity/.
// macOS only.
#if canImport(CoreGraphics)
import FlareCore
import FlareModel
import Foundation
import SuiteKernel
import SuiteUI
import Testing

@testable import FlareApp

/// Where the oracle and the suite's files live, found from this file's path.
enum LottieOracle {
    static let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent()
    static let binary = root.appending(path: ".build/lottie-oracle/render")
    static var built: Bool { FileManager.default.isExecutableFile(atPath: binary.path) }
}

@Suite(.enabled(if: LottieOracle.built,
                "LottiePlayerParityTests waits on the reference player: run scripts/lottie-oracle/build (LP-1)"))
struct LottiePlayerParityTests {
    static let root = LottieOracle.root, oracle = LottieOracle.binary
    static let work = root.appending(path: ".build/lottie-oracle/parity")

    enum OracleError: Error { case failed(status: Int32, bytes: Int) }

    /// The fixture `name`, opened as the CLI opens it.
    static func open(_ name: String) throws -> FlareHeadless {
        let url = root.appending(path: "Tests/AppSnapshotTests/Fixtures/Lottie/\(name).flare")
        return try FlareHeadless.open(try Data(contentsOf: url), name: "\(name).flare")
    }

    /// `doc`'s Lottie written to the work folder as `<name>.json`.
    static func exportLottie(_ doc: FlareHeadless, as name: String) throws -> URL {
        let file = try #require(try doc.export("lottie", options: .null).first)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        let url = work.appending(path: "\(name).json")
        try file.data.write(to: url)
        return url
    }

    /// The oracle's frame of `json` at `width` × `height`, kept beside it as `<name>.<frame>.rgba`.
    static func oracleFrame(_ json: URL, frame: Int, width: Int, height: Int) throws -> RGBAImage {
        let process = Process(), out = Pipe()
        process.executableURL = oracle
        process.arguments = [json.path, "\(frame)", "\(width)", "\(height)"]
        process.standardOutput = out
        try process.run()
        // Read before waiting: a frame is larger than the pipe's buffer.
        let bytes = try out.fileHandleForReading.readToEnd() ?? Data()
        process.waitUntilExit()
        guard process.terminationStatus == 0, bytes.count == width * height * 4 else {
            throw OracleError.failed(status: process.terminationStatus, bytes: bytes.count)
        }
        try bytes.write(to: json.deletingPathExtension().appendingPathExtension("\(frame).rgba"))
        return RGBAImage(width: width, height: height, bytes: [UInt8](bytes))
    }

    /// `StageRasterizer`'s frame of `doc`'s selected scene, over the scene's background.
    static func stageFrame(_ doc: FlareHeadless, frame: Int) throws -> RGBAImage {
        let document = try #require(doc.workspace.document), scene = try #require(doc.workspace.selectedScene)
        let list = LiveStage().drawList(document, sceneID: scene.id, frame: frame, editing: nil)
        return try #require(RGBAImage(png: try StageRasterizer().png(list, scale: 1, transparent: false)))
    }

    /// Whether `a` and `b` are the same frame by `FrameParity`'s rule.
    static func matches(_ a: RGBAImage, _ b: RGBAImage) -> Bool {
        a.width == b.width && a.height == b.height
            && FrameParity.matches(a.bytes, b.bytes, width: a.width, height: a.height)
    }

    /// Frames 0, the middle and the last of a scene `count` frames long.
    static func frames(_ count: Int) -> [Int] { [0, count / 2, max(count - 1, 0)] }

    @Test(arguments: ["bounce", "spinner", "stroke-on"])
    func theReferencePlayerDrawsWhatTheStageDraws(_ name: String) throws { try Self.parity(name) }

    @Test(.disabled("waits on the stage-matches-export fix"), arguments: ["colour-key", "trim"])
    func theReferencePlayerDrawsWhatTheStageDrawsAfterTheStageFix(_ name: String) throws { try Self.parity(name) }

    static func parity(_ name: String) throws {
        let doc = try Self.open(name), scene = try #require(doc.workspace.selectedScene)
        let json = try Self.exportLottie(doc, as: name)
        let (w, h) = (Int(scene.width), Int(scene.height))
        for frame in Self.frames(scene.durationFrames) {
            let player = try Self.oracleFrame(json, frame: frame, width: w, height: h)
            let stage = try Self.stageFrame(doc, frame: frame)
            let share = FrameParity.mismatch(player.bytes, stage.bytes, width: w, height: h)
            #expect(Self.matches(player, stage), "\(name) frame \(frame): \(share) of pixels differ")
        }
    }

    @Test(arguments: ["bounce", "spinner", "stroke-on"])
    func theLoopDoesNotRepeatFrameZero(_ name: String) throws { try Self.loop(name) }

    @Test(.disabled("waits on the stage-matches-export fix"), arguments: ["colour-key", "trim"])
    func theLoopDoesNotRepeatFrameZeroAfterTheStageFix(_ name: String) throws { try Self.loop(name) }

    static func loop(_ name: String) throws {
        let doc = try Self.open(name), scene = try #require(doc.workspace.selectedScene)
        let json = try Self.exportLottie(doc, as: name)
        let (w, h) = (Int(scene.width), Int(scene.height))
        let first = try Self.oracleFrame(json, frame: 0, width: w, height: h)
        let last = try Self.oracleFrame(json, frame: scene.durationFrames - 1, width: w, height: h)
        #expect(FrameParity.loopIsClean(first: first.bytes, last: last.bytes, width: w, height: h),
                "\(name) ends on frame 0")
    }

    /// The trap the suite exists for: keys one frame late play differently, so the compare must catch them.
    @Test func aKeyOneFrameLateFails() throws {
        let doc = try Self.open("bounce")
        var document = try #require(doc.workspace.document)
        let last = try #require(document.scenes.first).durationFrames - 1
        for s in document.scenes.indices {
            for l in document.scenes[s].layers.indices {
                document.scenes[s].layers[l].tracks = document.scenes[s].layers[l].tracks.mapValues { keys in
                    keys.map { var key = $0; key.frame = min(key.frame + 1, last); return key }
                }
            }
        }
        let late = try FlareHeadless.open(try FlareFormat.encode(document), name: "bounce-late.flare")
        let json = try Self.exportLottie(late, as: "bounce-late")
        let scene = try #require(doc.workspace.selectedScene), middle = scene.durationFrames / 2
        let player = try Self.oracleFrame(json, frame: middle, width: Int(scene.width), height: Int(scene.height))
        #expect(!Self.matches(player, try Self.stageFrame(doc, frame: middle)))
    }
}
#endif
