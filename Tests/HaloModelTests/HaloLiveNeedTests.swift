// HaloLiveNeedTests.swift: which live project a viewer leaf shows (CL-probe,
// #4589). A playhead leaf shows the playing frame, else the window's
// project, and never reads a scrub's or drag's preview, so an inspector
// scrub doesn't re-run the timeline strip, the timecode or the summaries;
// the drawn layers and handles show the preview first. On `reference` (50
// layers, every property keyed), a Rotation scrub's preview shows the same
// playhead, timecode, summary and drawn count as the window's project, so
// the playhead leaves lose nothing by skipping it. Linux and macOS.
@testable import HaloModel
import Testing

struct HaloLiveNeedTests {
    /// `reference` with its top layer selected, the playhead at `frame`.
    private func reference(at frame: Int = 0) throws -> HaloProject {
        var project = HaloProject(services: .fake)
        project.restore(try #require(HaloFixtures.project("reference")))
        let top = try #require(project.selectedComposition?.layers.first)
        project.selectLayer(top.id)
        project.scrub(to: frame)
        return project
    }

    @Test func aPlayheadLeafNeverReadsTheEdit() throws {
        let model = try reference()
        let playing = try reference(at: 30)
        var reads = 0
        let shown = HaloLiveNeed.playhead.shown(model, edit: { reads += 1; return model }, playing: { playing })
        #expect(reads == 0)
        #expect(shown.selectedComposition?.playheadFrame == 30)
        let paused = HaloLiveNeed.playhead.shown(model, edit: { reads += 1; return playing }, playing: { nil })
        #expect(reads == 0)
        #expect(paused.selectedComposition?.playheadFrame == 0)
    }

    @Test func drawnLeavesShowTheEditThenThePlayingFrame() throws {
        let model = try reference()
        var edit = model
        edit.setProperty(.rotation, to: 45)
        let playing = try reference(at: 30)
        let rotation = { (p: HaloProject) in p.propertyRows.first { $0.property == .rotation }?.value }
        #expect(rotation(HaloLiveNeed.drawn.shown(model, edit: { edit }, playing: { playing })) == 45)
        #expect(HaloLiveNeed.drawn.shown(model, edit: { nil }, playing: { playing }).selectedComposition?.playheadFrame == 30)
        #expect(HaloLiveNeed.drawn.shown(model, edit: { nil }, playing: { nil }) == model)
    }

    @Test func aRotationScrubLeavesEveryPlayheadReadoutAsItWas() throws {
        let model = try reference()
        var scrubbed = model
        for degrees in stride(from: 0.0, through: 180, by: 15) { scrubbed.setProperty(.rotation, to: degrees) }
        #expect(scrubbed.viewerDrawList != model.viewerDrawList)
        let shown = HaloLiveNeed.playhead.shown(model, edit: { scrubbed }, playing: { nil })
        #expect(shown.selectedComposition?.playheadFrame == scrubbed.selectedComposition?.playheadFrame)
        #expect(shown.selectedComposition?.statusTimecode == scrubbed.selectedComposition?.statusTimecode)
        #expect(shown.viewerSummary == scrubbed.viewerSummary)
        #expect(shown.viewerDrawList?.drawnSummary == scrubbed.viewerDrawList?.drawnSummary)
    }
}
