// HaloFrameRateTests.swift (frame-rates FR-7, slice FR-halo): Halo's frame-rate checks, turned on by FR-8, which
// gives a composition a `FrameRate`. An old 30 fps file opens and re-saves byte for byte (no `frameRate`
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

    @Test func oldFilesUnchanged() throws {
        let data = try Self.oldFile()
        let files = LiveProjectFiles()
        let state = try files.decode(data)
        let comp = try #require(state.compositions.first)
        #expect(comp.framesPerSecond == 30)
        #expect(comp.frameRate == FrameRate(whole: 30))
        let saved = try files.encode(state)
        #expect(saved == data, "an old 30 fps file changed bytes on save")
        #expect(!String(decoding: saved, as: UTF8.self).contains("\"frameRate\""), "a whole rate wrote frameRate")
    }

    @Test func renderUsesExactRate() throws {
        #expect(abs(Self.ntsc.seconds(ofFrame: 300) - 10.01) < 1e-9)
        let frames = Self.ntsc.frames(forDuration: 10)
        #expect(frames == 300)
        let settings = CompositionSettings(name: "NTSC", width: 320, height: 180, frameRate: Self.ntsc, durationSeconds: 10)
        #expect(settings.isValid && settings.durationFrames == frames)
        let comp = HaloComposition(id: "comp-1", name: "NTSC", width: 320, height: 180, frameRate: Self.ntsc, durationFrames: frames)
        let plan = try HaloRenderRules.plan(comp, HaloRenderSettings(format: .pngSequence))
        #expect(plan.fileNames.count == 300)
        #expect(plan.frameRate == Self.ntsc && plan.framesPerSecond == 30)
        let timed = { (frame: Int) in plan.seconds(ofFrame: frame) }
        #expect(abs(timed(300) - Self.ntsc.seconds(ofFrame: 300)) < 1e-6, "frame 300 isn't at 10.01 s")
        #expect(abs(timed(299) - 299.0 * 1001 / 30000) < 1e-6, "frame 299 drifted from 299 x 1001 / 30000 s")
    }

    @Test func exactRateRoundTripsInTheFile() throws {
        var state = HaloDocumentState()
        state.compositions = [HaloComposition(id: "comp-1", name: "NTSC", width: 320, height: 180, frameRate: Self.ntsc, durationFrames: 300)]
        let files = LiveProjectFiles()
        let saved = try files.encode(state)
        #expect(String(decoding: saved, as: UTF8.self).contains("\"frameRate\""))
        let opened = try files.decode(saved)
        #expect(opened.compositions.first?.frameRate == Self.ntsc)
        #expect(opened.compositions.first?.framesPerSecond == 30)
    }

    @Test func setFrameRateKeepsFramesAndUndoes() throws {
        var project = HaloProject()
        project.newComposition(CompositionSettings(name: "Comp"))
        let before = try #require(project.selectedComposition)
        let set = project.setFrameRate(Self.ntsc)
        #expect(set)
        #expect(project.selectedComposition?.frameRate == Self.ntsc)
        #expect(project.selectedComposition?.durationFrames == before.durationFrames)
        let again = project.setFrameRate(Self.ntsc), offList = project.setFrameRate(FrameRate(whole: 23))
        #expect(!again, "the same rate is no step")
        #expect(!offList, "a rate off the list is refused")
        project.undo()
        #expect(project.selectedComposition?.frameRate == before.frameRate)
    }

    @Test func timecodeCountsDropFrame() {
        var comp = HaloComposition(id: "comp-1", name: "NTSC", width: 320, height: 180, frameRate: Self.ntsc, durationFrames: 3000)
        #expect(comp.timecode(300) == "00:00:10;00")
        comp.playheadFrame = 1800
        #expect(comp.playheadTimecode == "00:01:00;02")
    }

    @Test func playbackClockRunsAtExactRate() {
        #expect(abs(HaloProject.clockSeconds(10.01, at: Self.ntsc) * 30 - 300) < 1e-6)
        #expect(HaloProject.clockSeconds(2, at: FrameRate(whole: 24)) == 2)
    }
}
