// FlareExportBudgetTests.swift (quality gate #6200, QB-L8): Flare's export budget timed on the real writers, the
// way `afterglow flare export` runs them: the showcase at 1920 x 1080 (mask, symbol, gradients) through the CLI on a
// FakeIO, so PNG frames go through FlareRaster and the CLI's CoreRaster PNG encoder (the encode FlareModelTests' QB-L8
// can't reach). Budget row: SVG frame < 1 s, Lottie of 300 frames < 10 s, 48 PNG frames at 1080p < 10 s. Wall clock,
// so it waits for its Tests/perf-suites.txt line; run it on a release build:
// `swift test -c release -Xswiftc -enable-testing --filter FlareExportBudgetTests`.
import AfterGlowCLICore
import FlareCore
import FlareModel
import Foundation
import Testing

@Suite struct FlareExportBudgetTests {
    static func hd(_ frames: Int) throws -> Data {
        var document = FlareFixtures.showcase
        (document.scenes[0].width, document.scenes[0].height, document.scenes[0].durationFrames) = (1920, 1080, frames)
        return try FlareFormat.encode(document)
    }

    /// `afterglow flare export hd.flare --format <format> --out out --json <options>`: its time and the files it wrote.
    static func export(_ frames: Int, _ format: String, _ options: String) throws -> (Duration, [String: Data]) {
        let io = FakeIO(files: ["hd.flare": try hd(frames)])
        var code: Int32 = -1
        let time = ContinuousClock().measure {
            code = CLI.run(["flare", "export", "hd.flare", "--format", format, "--out", "out", "--json", options], io: io)
        }
        #expect(code == 0, "\(format) export exited \(code): \(io.stderr)")
        return (time, io.files.filter { $0.key.hasPrefix("out") })
    }

    @Test(.disabled("report-only: enable once Tests/perf-suites.txt lists AfterGlowCLITests.FlareExportBudgetTests"))
    func svgFrameLottieAndPNGSequenceStayInsideQBL8OnTheRealWriters() throws {
        let (svg, svgs) = try Self.export(48, "svg", #"{"frames":[24]}"#)
        let (lottie, lotties) = try Self.export(300, "lottie", #"{"dropText":true}"#)
        let frames = (0...47).map(String.init).joined(separator: ",")
        let (png, pngs) = try Self.export(48, "png", #"{"frames":[\#(frames)],"dropText":true}"#)
        print("QB-L8 real writers: svg \(svg) lottie \(lottie) png48@1080p \(png)")
        #expect(svgs.count == 1 && lotties.count == 1)
        let signature = Data([137, 80, 78, 71, 13, 10, 26, 10])
        #expect(pngs.count == 48 && pngs.values.allSatisfy { $0.starts(with: signature) && $0.count < 1920 * 1080 * 4 },
                "not 48 encoded PNGs: \(pngs.count) files")
        #expect(svg < .seconds(1) && lottie < .seconds(10) && png < .seconds(10))
    }
}
