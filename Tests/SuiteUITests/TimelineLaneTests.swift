// TimelineLaneTests.swift: TL-6's lane geometry and key hit (timeline packet,
// acceptance row TL-6). A clip block runs tick to tick past the strip's
// inset, never narrower than a key; its height is the bed's less 4 pt and its
// radius the lane's, capped at half its height. A press picks the nearer of
// two keys and hits within half the 16 pt token, not the 10 pt draw size
// (B11). macOS only.
import Foundation
@testable import SuiteUI
import Testing

@Suite struct TimelineLaneTests {
    private static let mapping = FrameMapping(duration: 120, frameWidth: 10)
    private static let bed = TimelineLaneGeometry.bed(width: 1_000, height: SuiteSize.timelineLane)

    @Test func aSpanRunsTickToTickPastTheInset() {
        let block = TimelineLaneGeometry.block(20...50, mapping: Self.mapping, bed: Self.bed)
        #expect(block.minX == timelineInset + 200)
        #expect(block.maxX == timelineInset + 500)
    }

    @Test func aOneFrameSpanIsAKeyWide() {
        let block = TimelineLaneGeometry.block(20...20, mapping: Self.mapping, bed: Self.bed)
        #expect(block.width == 10)
        let narrow = FrameMapping(duration: 120, frameWidth: 2)
        #expect(TimelineLaneGeometry.block(20...21, mapping: narrow, bed: Self.bed).width == SuiteSize.timelineKeyframe)
    }

    @Test func theBedLeavesTwoPointsAboveAndBelowAndTheBlockSitsInsideIt() {
        #expect(Self.bed.minY == 2)
        #expect(Self.bed.height == SuiteSize.timelineLane - 4)
        let block = TimelineLaneGeometry.block(20...50, mapping: Self.mapping, bed: Self.bed)
        #expect(block.height == Self.bed.height - 4)
        #expect(block.midY == Self.bed.midY)
        #expect(TimelineLaneGeometry.radius(of: block) == min(SuiteRadius.lane, block.height / 2))
    }

    @Test func keysTwelvePointsApartPickTheNearer() {
        let mapping = FrameMapping(duration: 120, frameWidth: 12)
        let track = TimelineTrack(id: "a", name: "A", keyframes: [10, 11])
        #expect(TimelineLaneHit.key(atX: timelineInset + 125, on: track, mapping: mapping) == 10)
        #expect(TimelineLaneHit.key(atX: timelineInset + 128, on: track, mapping: mapping) == 11)
    }

    @Test func aPressSevenPointsFromAKeyHitsAndNineMisses() {
        let track = TimelineTrack(id: "a", name: "A", keyframes: [10])
        let key = timelineInset + 100
        #expect(TimelineLaneHit.key(atX: key + 7, on: track, mapping: Self.mapping) == 10)
        #expect(TimelineLaneHit.key(atX: key - 7, on: track, mapping: Self.mapping) == 10)
        #expect(TimelineLaneHit.key(atX: key + 9, on: track, mapping: Self.mapping) == nil)
        #expect(TimelineLaneHit.key(atX: key - 9, on: track, mapping: Self.mapping) == nil)
    }
}
