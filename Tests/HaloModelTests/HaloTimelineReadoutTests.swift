// HaloTimelineReadoutTests.swift: a lane's `keysReadout`, the text the
// hidden `halo.timeline.keys` element carries for the journeys (#262).
import Testing

@testable import HaloModel

@Suite struct HaloTimelineReadoutTests {
    @Test func namesTheLayerAndCountsItsKeyFramesOnce() throws {
        let project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("keyed")))
        let readouts = project.timelineRows.map(\.keysReadout)
        // Ball: x at 0 and 24, opacity at 0 and 12, so frames 0, 12 and 24.
        #expect(readouts == ["Ball: 3 keyframes", "Floor: 0 keyframes"])
    }

    @Test func followsANewKey() throws {
        let row = HaloTimelineRow(id: "a", name: "Title", span: 0...10, isSelected: false, keyFrames: [2, 5])
        #expect(row.keysReadout == "Title: 2 keyframes")
    }
}
