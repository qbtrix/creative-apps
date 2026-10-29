// DesignTimelineTracksTests.swift: the rows Design's timeline slot shows and its slide-in rule (one-document
// OD-12): a still document shows no slot; each keyed layer is one row, parents first; keys of x, y and opacity
// merge by frame, shaped by their easing. Runs on Linux and macOS.
@testable import DesignModel
import SuiteKernel
import Testing

@Suite struct DesignTimelineTracksTests {
    @Test func aStillDocumentShowsNoTimeline() {
        let still = DesignFixtures.cards
        #expect(!still.showsTimeline)
        #expect(still.timelineRows.isEmpty)
        #expect(DesignFixtures.animated(1).showsTimeline)
    }

    @Test func everyKeyedLayerIsOneRowParentsFirst() throws {
        let rows = DesignFixtures.animated(50).timelineRows
        try #require(rows.count == 51)
        #expect(rows.first?.id == "node-1" && rows.first?.name == "Frame 1")
        #expect(rows[1].id == "node-2" && rows.last?.id == "node-51")
    }

    @Test func keysOfEveryPropertyMergeByFrameAndShowTheirEasing() throws {
        var doc = DesignFixtures.animated(1)
        doc.pages[0].nodes[0].children[0].time = DesignNodeTime(tracks: [
            .x: [Keyframe(frame: 0, value: 0, easing: .easeIn), Keyframe(frame: 120, value: 5)],
            .opacity: [Keyframe(frame: 0, value: 1), Keyframe(frame: 60, value: 0.5, easing: .hold)],
        ])
        let rows = doc.timelineRows
        try #require(rows.count == 2, "the keyed child is its own row")
        let row = rows[1]
        #expect(row.keys.map(\.frame) == [0, 60, 120])
        #expect(row.keys.map(\.shape) == [.eased, .hold, .linear], "x leads at frame 0; opacity alone keys 60")
    }

    @Test func theTimelineSpansTheDocumentsLength() {
        #expect(DesignFixtures.animated(1).timelineLastFrame == 299)
    }
}
