// TimelineNavTests.swift: the timeline strip's navigation rules (timeline
// packet, TL-16). TimelineZoom: zoom In and Out step along ViewerZoom's stops
// and stop at fit (1) and at 64 pt per frame; the anchor frame keeps its
// screen x; the follow rule jumps a page once the playhead leaves the view.
// TimelineTime: frames and timecode labels, frames when fps is 0 (no
// division), and timecode ruler labels on whole seconds once the frame step
// reaches fps / 2. No SwiftUI. macOS only (SuiteUI).
import SuiteUI
import Testing

@Suite struct TimelineNavTests {
    // MARK: TimelineZoom

    @Test func zoomStepsFollowViewerZoomsStopsAndStopAt64PointsPerFrame() {
        // 4 pt per frame: the top is 16 (64 pt per frame).
        var zoom = 1.0
        var seen: [Double] = []
        for _ in 0..<12 {
            zoom = TimelineZoom.zoomedIn(from: zoom, frameWidth: 4)
            seen.append(zoom)
        }
        #expect(seen == [1.5, 2, 3, 4, 6, 8, 12, 16, 16, 16, 16, 16])
        #expect(4 * zoom == 64)
        // 10 pt per frame: the top is 6.4, between two stops.
        #expect(TimelineZoom.zoomedIn(from: 6, frameWidth: 10) == 6.4)
        #expect(TimelineZoom.zoomedIn(from: 6.4, frameWidth: 10) == 6.4)
        #expect(TimelineZoom.zoomedOut(from: 6.4, frameWidth: 10) == 6)
    }

    @Test func zoomOutStopsAtFit() {
        #expect(TimelineZoom.zoomedOut(from: 2, frameWidth: 10) == 1.5)
        #expect(TimelineZoom.zoomedOut(from: 1.5, frameWidth: 10) == 1)
        #expect(TimelineZoom.zoomedOut(from: 1, frameWidth: 10) == 1)
        #expect(TimelineZoom.clamped(0.25, frameWidth: 10) == 1)
        #expect(TimelineZoom.clamped(.nan, frameWidth: 10) == 1)
        #expect(TimelineZoom.clamped(100, frameWidth: 10) == 6.4)
    }

    @Test func aHostWiderThan64PointsPerFrameNeverZooms() {
        #expect(TimelineZoom.range(frameWidth: 80) == 1...1)
        #expect(TimelineZoom.range(frameWidth: 0) == 1...1)
        #expect(TimelineZoom.range(frameWidth: .nan) == 1...1)
        #expect(TimelineZoom.zoomedIn(from: 1, frameWidth: 80) == 1)
    }

    @Test func thePointersFrameKeepsItsScreenX() {
        let w = 10.0, offset = 100.0, pointer = 300.0
        let frame = 40   // 40 * 10 - 100 = 300: under the pointer
        #expect(TimelineZoom.x(ofFrame: frame, frameWidth: w, zoom: 1, offset: offset) == pointer)
        for new in [1.5, 2, 6.4] {
            let moved = TimelineZoom.anchoredOffset(offset, anchorX: pointer, from: 1, to: new)
            let x = TimelineZoom.x(ofFrame: frame, frameWidth: w, zoom: new, offset: moved)
            #expect(abs(x - pointer) <= 0.5)
        }
        // Zooming back out returns it there too.
        let inOffset = TimelineZoom.anchoredOffset(offset, anchorX: pointer, from: 1, to: 3)
        let back = TimelineZoom.anchoredOffset(inOffset, anchorX: pointer, from: 3, to: 1.5)
        #expect(abs(TimelineZoom.x(ofFrame: frame, frameWidth: w, zoom: 1.5, offset: back) - pointer) <= 0.5)
    }

    @Test func theKeysAnchorThePlayhead() {
        let w = 10.0, offset = 0.0, playhead = 30
        let anchor = TimelineZoom.x(ofFrame: playhead, frameWidth: w, zoom: 1, offset: offset)
        let next = TimelineZoom.zoomedIn(from: 1, frameWidth: w)
        let moved = TimelineZoom.anchoredOffset(offset, anchorX: anchor, from: 1, to: next)
        #expect(abs(TimelineZoom.x(ofFrame: playhead, frameWidth: w, zoom: next, offset: moved) - anchor) <= 0.5)
        #expect(TimelineZoom.anchoredOffset(offset, anchorX: anchor, from: 0, to: next) == offset)
    }

    @Test func theOffsetStaysInsideTheContent() {
        // 100 frames at 10 pt, zoom 2: 2000 pt of content in a 500 pt view.
        #expect(TimelineZoom.clampedOffset(-40, lastFrame: 100, frameWidth: 10, zoom: 2, viewport: 500) == 0)
        #expect(TimelineZoom.clampedOffset(9000, lastFrame: 100, frameWidth: 10, zoom: 2, viewport: 500) == 1500)
        #expect(TimelineZoom.clampedOffset(700, lastFrame: 100, frameWidth: 10, zoom: 2, viewport: 500) == 700)
        #expect(TimelineZoom.clampedOffset(700, lastFrame: 10, frameWidth: 10, zoom: 1, viewport: 500) == 0)
    }

    @Test func followJumpsAPageWhenThePlayheadLeavesTheView() {
        // 20 pt per frame, a 400 pt view at offset 0 shows frames 0 to 19.
        #expect(TimelineZoom.followed(0, playhead: 19, frameWidth: 10, zoom: 2, viewport: 400) == 0)
        #expect(TimelineZoom.followed(0, playhead: 20, frameWidth: 10, zoom: 2, viewport: 400) == 400)
        #expect(TimelineZoom.followed(400, playhead: 45, frameWidth: 10, zoom: 2, viewport: 400) == 800)
        // A loop back to 0 shows frame 0 again.
        #expect(TimelineZoom.followed(800, playhead: 0, frameWidth: 10, zoom: 2, viewport: 400) == 0)
        #expect(TimelineZoom.followed(250, playhead: 15, frameWidth: 10, zoom: 2, viewport: 400) == 250)
        #expect(TimelineZoom.followed(250, playhead: 90, frameWidth: 10, zoom: 2, viewport: 0) == 250)
    }

    // MARK: TimelineTime

    @Test func labelsReadFramesAndTimecode() {
        #expect(TimelineTime.label(frame: 30, fps: 24, unit: .frames) == "30")
        #expect(TimelineTime.label(frame: 30, fps: 24, unit: .timecode) == "00:01:06")
        #expect(TimelineTime.label(frame: 0, fps: 24, unit: .timecode) == "00:00:00")
        #expect(TimelineTime.label(frame: 24 * 61 + 5, fps: 24, unit: .timecode) == "01:01:05")
        #expect(TimelineTime.label(frame: 24 * 3600, fps: 24, unit: .timecode) == "1:00:00:00")
        #expect(TimelineTime.label(frame: 30 * 3661 + 7, fps: 30, unit: .timecode) == "1:01:01:07")
        #expect(TimelineTime.label(frame: -30, fps: 24, unit: .timecode) == "-00:01:06")
    }

    @Test func noFpsReadsFramesWithoutDividing() {
        #expect(TimelineTime.label(frame: 30, fps: 0, unit: .timecode) == "30")
        #expect(TimelineTime.label(frame: 30, fps: -24, unit: .timecode) == "30")
    }

    @Test func timecodeLabelsSitOnWholeSecondsOnceTheStepReachesHalfASecond() {
        // Below fps / 2 the step stands.
        #expect(TimelineTime.labelFrames(in: 0...30, step: 5, fps: 24, unit: .timecode) == [0, 5, 10, 15, 20, 25, 30])
        // From fps / 2 on: whole seconds.
        #expect(TimelineTime.labelFrames(in: 0...72, step: 12, fps: 24, unit: .timecode) == [0, 24, 48, 72])
        #expect(TimelineTime.labelFrames(in: 10...100, step: 30, fps: 24, unit: .timecode) == [48, 96])
        // Frames, or no fps: the step stands.
        #expect(TimelineTime.labelFrames(in: 0...36, step: 12, fps: 24, unit: .frames) == [0, 12, 24, 36])
        #expect(TimelineTime.labelFrames(in: 0...24, step: 12, fps: 0, unit: .timecode) == [0, 12, 24])
        #expect(TimelineTime.labelStep(12, fps: 24, unit: .timecode) == 24)
        #expect(TimelineTime.labelStep(11, fps: 24, unit: .timecode) == 11)
        #expect(TimelineTime.labelStep(0, fps: 24, unit: .frames) == 1)
    }
}
