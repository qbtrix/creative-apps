// TimelineLaneLayersTests.swift: TL-20's lane-layer rules (timeline packet,
// acceptance row TL-20). Lanes 2 and 5 of 8 changed give exactly {2, 5} to
// redraw; the layer frames tile the strip's lane area from the top with no
// gap or overlap, ending at TimelineStripLayout.lanesHeight; a press at a
// key's 16 pt token routes `.key`, at a clip end `.clipEnd`, on the bed
// `.bed`, strictly inside half the playhead's 16 pt band `.playheadBand`
// (8 pt out is the bed), and off every lane nowhere. macOS only.
import Foundation
@testable import SuiteUI
import Testing

@MainActor @Suite struct TimelineLaneLayersTests {
    private static let mapping = FrameMapping(duration: 120, frameWidth: 10)
    private static let lane = SuiteSize.timelineLane

    /// Eight lanes, each with a key at 30 and a clip 20...50.
    private static let lanes: [TimelineTrack<String>] = (0..<8).map {
        TimelineTrack(id: "lane-\($0)", name: "Lane \($0)", keys: [TimelineKey(frame: 30, shape: .linear)], spans: [20...50])
    }

    /// A press `x` points past the inset, on lane `row`'s middle, with the playhead at `playhead`.
    private func route(_ x: CGFloat, row: Int = 3, playhead: Int = 100, lanes: [TimelineTrack<String>] = Self.lanes) -> TimelineLaneLayers.Route? {
        TimelineLaneLayers.route(
            press: CGPoint(x: timelineInset + x, y: Self.lane * (CGFloat(row) + 0.5)), in: lanes,
            mapping: Self.mapping, playhead: playhead)
    }

    @Test func lanesTwoAndFiveOfEightChangedRedrawExactlyThose() {
        var new = Self.lanes
        new[2] = TimelineTrack(id: "lane-2", name: "Lane 2", keys: [TimelineKey(frame: 31, shape: .linear)], spans: [20...50])
        new[5] = TimelineTrack(
            id: "lane-5", name: "Lane 5", keys: [TimelineKey(frame: 30, shape: .linear)], spans: [20...50], isSelected: true)
        #expect(TimelineLaneLayers.dirty(old: Self.lanes, new: new) == [2, 5])
        #expect(TimelineLaneLayers.dirty(old: Self.lanes, new: Self.lanes).isEmpty)
        #expect(TimelineLaneLayers.dirty(old: [1, 2, 3], new: [1, 2, 3, 4, 5]) == [3, 4], "an added lane is dirty")
        #expect(TimelineLaneLayers.dirty(old: [1, 2, 3], new: [1, 2]).isEmpty)
        #expect(TimelineLaneLayers.dirty(old: [1, 2, 3], new: [9, 2]) == [0])
    }

    @Test func framesTileTheLaneAreaWithNoGapOrOverlap() {
        let frames = TimelineLaneLayers.frames(count: 8, width: 1_000)
        #expect(frames.count == 8)
        #expect(frames.first?.minY == 0)
        for (above, below) in zip(frames, frames.dropFirst()) {
            #expect(above.maxY == below.minY, "lane \(above) and \(below) gap or overlap")
        }
        #expect(frames.allSatisfy { $0.minX == 0 && $0.width == 1_000 && $0.height == Self.lane })
        #expect(frames.last?.maxY == TimelineStripLayout(trackCount: 8, toolbar: false).lanesHeight)
    }

    @Test func spacingSitsBetweenFramesAndBrokenNumbersAreZero() {
        let spaced = TimelineLaneLayers.frames(count: 3, laneHeight: 20, spacing: 4, width: 300)
        #expect(spaced.map(\.minY) == [0, 24, 48])
        #expect(spaced.map(\.height) == [20, 20, 20])
        #expect(TimelineLaneLayers.frames(count: -2, width: 300).isEmpty)
        let broken = TimelineLaneLayers.frames(count: 2, laneHeight: -5, spacing: .nan, width: .infinity)
        #expect(broken.map(\.height) == [0, 0] && broken.map(\.width) == [0, 0])
    }

    @Test func laneAtYIsTheRowUnderThePoint() {
        #expect(TimelineLaneLayers.lane(atY: 0, count: 8) == 0)
        #expect(TimelineLaneLayers.lane(atY: Self.lane * 3 + 1, count: 8) == 3)
        #expect(TimelineLaneLayers.lane(atY: Self.lane * 8 - 0.5, count: 8) == 7)
        #expect(TimelineLaneLayers.lane(atY: Self.lane * 8, count: 8) == nil)
        #expect(TimelineLaneLayers.lane(atY: -1, count: 8) == nil && TimelineLaneLayers.lane(atY: 10, count: 0) == nil)
        #expect(TimelineLaneLayers.lane(atY: 1e300, count: 8) == nil && TimelineLaneLayers.lane(atY: .nan, count: 8) == nil)
        // 20 pt lanes 4 pt apart: 21 is in the gap after lane 0, 24 starts lane 1.
        #expect(TimelineLaneLayers.lane(atY: 21, count: 3, laneHeight: 20, spacing: 4) == nil)
        #expect(TimelineLaneLayers.lane(atY: 24, count: 3, laneHeight: 20, spacing: 4) == 1)
    }

    @Test func aPressAtAKeysTokenRoutesTheKeyAndPastItTheBed() {
        #expect(route(300) == TimelineLaneLayers.Route(lane: 3, press: .key(30)))
        #expect(route(300 + 8, row: 6) == TimelineLaneLayers.Route(lane: 6, press: .key(30)))
        #expect(route(300 - 8, row: 0)?.press == .key(30) && route(300 + 9)?.press == .bed, "half the 16 pt token")
        #expect(route(100) == TimelineLaneLayers.Route(lane: 3, press: .bed))
        #expect(route(700, row: 7) == TimelineLaneLayers.Route(lane: 7, press: .bed))
    }

    @Test func aPressAtAClipEndRoutesTheEnd() {
        #expect(route(500 - 5) == TimelineLaneLayers.Route(lane: 3, press: .clipEnd(TimelineClipEnd(span: 20...50, edge: .end))))
        #expect(route(200 + 5)?.press == .clipEnd(TimelineClipEnd(span: 20...50, edge: .start)))
        #expect(route(500 + 7)?.press == .bed, "7 pt is past the 6 pt grab zone")
    }

    @Test func aPressInsideThePlayheadBandRoutesTheBandAndEightPointsOutIsTheBed() {
        let half = TimelinePlayheadGrab.band / 2
        #expect(route(1_000) == TimelineLaneLayers.Route(lane: 3, press: .playheadBand))
        #expect(route(1_000 + half - 0.5)?.press == .playheadBand)
        #expect(route(1_000 - half + 0.5)?.press == .playheadBand)
        #expect(route(1_000 + half)?.press == .bed, "the band's edge is strictly inside")
        #expect(route(1_000 - half)?.press == .bed, "the band's edge is strictly inside")
        // A key under the band goes to the band, as the strip's playhead layer takes the press today.
        #expect(route(300, playhead: 30)?.press == .playheadBand)
        #expect(route(300 - 8, playhead: 30)?.press == .key(30), "8 pt out of the band is the key's token")
    }

    @Test func aPressOffEveryLaneRoutesNowhere() {
        let above = CGPoint(x: timelineInset + 300, y: -1)
        #expect(TimelineLaneLayers.route(press: above, in: Self.lanes, mapping: Self.mapping, playhead: 100) == nil)
        let below = CGPoint(x: timelineInset + 300, y: Self.lane * 8)
        #expect(TimelineLaneLayers.route(press: below, in: Self.lanes, mapping: Self.mapping, playhead: 100) == nil)
        #expect(route(300, lanes: []) == nil)
        let broken = CGPoint(x: .nan, y: Self.lane * 3.5)
        #expect(TimelineLaneLayers.route(press: broken, in: Self.lanes, mapping: Self.mapping, playhead: 100) == nil)
    }
}
