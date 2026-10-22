// HaloFrameRateTests.swift (frame-rates FR-7, slice FR-halo): Halo's frame-rate checks, written first and disabled
// until FR-8 gives a composition a `FrameRate`. An old 30 fps file opens and re-saves byte for byte (no `frameRate`
// key appears for a whole rate), and a 29.97 composition's render times frame 300 at 10.01 s and frame 299 at
// 299 x 1001 / 30000 s, never by a rate rounded to 30. The expected times come from SuiteKernel's `FrameRate`.
// Linux and macOS.
import Foundation
@testable import HaloModel
import SuiteKernel
import Testing

@Suite struct HaloFrameRateTests {
    /// The old-format 30 fps composition file: `Fixtures/comp-30fps.halo`, as today's encoder writes it.
    static func oldFile() throws -> Data {
        try Data(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/comp-30fps.halo"))
    }

    /// 29.97 fps, the NTSC rate.
    static let ntsc = FrameRate(numerator: 30000, denominator: 1001)

    @Test(.disabled("waits on FR-8")) func oldFilesUnchanged() throws {
        let data = try Self.oldFile()
        let files = LiveProjectFiles()
        let state = try files.decode(data)
        let comp = try #require(state.compositions.first)
        #expect(comp.framesPerSecond == 30)
        // FR-8: also #expect(comp.frameRate == FrameRate(whole: 30)).
        let saved = try files.encode(state)
        #expect(saved == data, "an old 30 fps file changed bytes on save")
        #expect(!String(decoding: saved, as: UTF8.self).contains("\"frameRate\""), "a whole rate wrote frameRate")
    }

    @Test(.disabled("waits on FR-8")) func renderUsesExactRate() throws {
        #expect(abs(Self.ntsc.seconds(ofFrame: 300) - 10.01) < 1e-9)
        let frames = Self.ntsc.frames(forDuration: 10)
        #expect(frames == 300)
        // FR-8: built at Self.ntsc (CompositionSettings.frameRate), not the whole 30 today's API can hold.
        let comp = HaloComposition(id: "comp-1", name: "NTSC", width: 320, height: 180, framesPerSecond: 30, durationFrames: frames)
        let plan = try HaloRenderRules.plan(comp, HaloRenderSettings(format: .pngSequence))
        #expect(plan.fileNames.count == 300)
        // FR-8: the plan's exact-rate frame time (plan.frameRate.seconds(ofFrame:)) replaces this whole-rate division.
        let timed = { (frame: Int) in Double(frame) / Double(max(plan.framesPerSecond, 1)) }
        #expect(abs(timed(300) - Self.ntsc.seconds(ofFrame: 300)) < 1e-6, "frame 300 isn't at 10.01 s")
        #expect(abs(timed(299) - 299.0 * 1001 / 30000) < 1e-6, "frame 299 drifted from 299 x 1001 / 30000 s")
    }
}
