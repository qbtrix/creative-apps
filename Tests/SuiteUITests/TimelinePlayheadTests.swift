// TimelinePlayheadTests.swift: TL-8's playhead (timeline packet, acceptance
// row TL-8). A press inside half the 16 pt band beside the line, down in a
// lane, grabs it and one 9 pt off doesn't; the pill grabs too. A drag that
// stays on one frame sends one onScrub, and none at the playhead's own frame.
// The pill reads the playhead in the host's unit. Lanes outside the work
// area dim from the inset to its first tick and from its last tick to the
// end; no work area, or one over every frame, dims nothing. A row partly in
// view, at either edge, counts as shown. macOS only.
import Foundation
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor @Suite struct TimelinePlayheadTests {
    private static let mapping = FrameMapping(duration: 59, frameWidth: 10)

    @Test func aPressSevenPointsBesideTheLineInALaneGrabsItAndNineDoesNot() {
        let lineX: CGFloat = 300
        let pill = TimelinePlayheadGrab.pill(lineX: lineX, label: "30", width: 600)
        let shape = TimelinePlayheadGrab.shape(lineX: lineX, pill: pill, height: 400)
        let laneY = SuiteSize.timelineRuler + SuiteSize.timelineLane * 4.5
        #expect(shape.contains(CGPoint(x: lineX + 7, y: laneY)))
        #expect(shape.contains(CGPoint(x: lineX - 7, y: laneY)))
        #expect(!shape.contains(CGPoint(x: lineX + 9, y: laneY)))
        #expect(!shape.contains(CGPoint(x: lineX - 9, y: laneY)))
        #expect(shape.contains(CGPoint(x: pill.maxX - 1, y: pill.midY)))
    }

    @Test func draggingOverTheSameFrameSendsOneScrub() {
        let sender = TimelineScrubSender()
        var sent: [Int] = []
        for frame in [30, 31, 31, 31, 32, 32] { sender.send(frame, from: 30) { sent.append($0) } }
        #expect(sent == [31, 32])
        sender.end()
        sender.send(32, from: 32) { sent.append($0) }
        #expect(sent == [31, 32])
    }

    @Test func thePillReadsThirtyAtThirty() {
        let playhead = TimelinePlayhead(
            mapping: Self.mapping, playhead: 30, unit: .frames, fps: 24, scroll: .zero, keys: [], onScrub: { _ in })
        #expect(playhead.label == "30")
        let pill = TimelinePlayheadGrab.pill(lineX: tickX(Self.mapping, 30), label: playhead.label, width: 600)
        #expect(abs(pill.midX - tickX(Self.mapping, 30)) < 0.5)
        #expect(pill.minY >= 0 && pill.maxY <= SuiteSize.timelineRuler)
    }

    /// SJ19d finds the pill in timecode by this pattern on its text (#2503).
    @Test func thePillInTimecodeReadsTheJourneysPattern() {
        let long = FrameMapping(duration: 9_999, frameWidth: 2)
        let playhead = TimelinePlayhead(
            mapping: long, playhead: 360, unit: .timecode, fps: 24, scroll: .zero, keys: [], onScrub: { _ in })
        #expect(playhead.label == "00:15:00")
        let pattern = NSPredicate(format: "SELF MATCHES %@", #"\d\d:\d\d:\d\d"#)
        #expect(pattern.evaluate(with: playhead.label))
        #expect(!pattern.evaluate(with: "360"))
    }

    @Test func onlyKeysAtThePlayheadOnRowsInViewAreDrawnKeyed() {
        let tracks = [
            TimelineTrack(id: 0, name: "A", keys: [TimelineKey(frame: 30, shape: .eased)], pickedFrames: [30]),
            TimelineTrack(id: 1, name: "B", keyframes: [12]),
            TimelineTrack(id: 2, name: "C", keyframes: [30]),
        ]
        let keys = TimelinePlayhead.keys(at: 30, in: tracks, rows: 0..<9)
        #expect(keys.map(\.row) == [0, 2])
        #expect(keys.map(\.picked) == [true, false])
        #expect(keys.map(\.glyph) == [.circle, .diamond])
        #expect(TimelinePlayhead.keys(at: 30, in: tracks, rows: 1..<2).isEmpty)
        let lane = Double(SuiteSize.timelineLane)
        #expect(TimelinePlayhead.rows(showing: lane * 2...lane * 5, count: 300) == 2..<5)
        #expect(TimelinePlayhead.rows(showing: nil, count: 3) == 0..<3)
    }

    /// A row half under the ruler or half off the bottom is still in view, so its key draws keyed (#1745).
    @Test func aRowPartlyInViewStillDrawsItsKeyKeyed() {
        let lane = Double(SuiteSize.timelineLane)
        #expect(TimelinePlayhead.rows(showing: lane * 2.5...lane * 4.5, count: 300) == 2..<5)
        #expect(TimelinePlayhead.rows(showing: lane * 2.5...lane * 5, count: 300) == 2..<5)
        #expect(TimelinePlayhead.rows(showing: lane * 2...lane * 4.5, count: 300) == 2..<5)
    }

    @Test func lanesOutsideTheWorkAreaDimFromTheInsetAndToTheEnd() {
        let width: CGFloat = 600
        let dims = TimelinePlayheadGrab.dims(mapping: Self.mapping, workArea: 10...40, scrollX: 0, width: width)
        let lastTick = tickX(Self.mapping, Self.mapping.duration)
        let expected: [ClosedRange<CGFloat>] = [timelineInset...tickX(Self.mapping, 10), tickX(Self.mapping, 40)...lastTick]
        #expect(dims == expected)
        let first = dims.first?.upperBound ?? 0
        let lower: CGFloat = 108
        #expect(first == lower)
        #expect(TimelinePlayheadGrab.dims(mapping: Self.mapping, workArea: nil, scrollX: 0, width: width).isEmpty)
        let full = 0...Self.mapping.duration
        #expect(TimelinePlayheadGrab.dims(mapping: Self.mapping, workArea: full, scrollX: 0, width: width).isEmpty)
    }

    @Test func theDimsFollowTheScrollAndStayInTheLayer() {
        let scrolled = TimelinePlayheadGrab.dims(mapping: Self.mapping, workArea: 10...40, scrollX: 300, width: 150)
        let expected: [ClosedRange<CGFloat>] = [tickX(Self.mapping, 40) - 300...150]
        #expect(scrolled == expected)
        let playhead = TimelinePlayhead(
            mapping: Self.mapping, playhead: 30, unit: .frames, fps: 24, scroll: .zero, keys: [], onScrub: { _ in })
        let worked = TimelinePlayhead(
            mapping: Self.mapping, playhead: 30, unit: .frames, fps: 24, scroll: .zero, keys: [], workArea: 10...40,
            onScrub: { _ in })
        #expect(playhead != worked)
    }

    /// The pill hides each ruler label it touches whole: in timecode a label
    /// runs right of its tick past the pill, and half of one read "06" beside
    /// it (Mac finish). Labels clear of the pill keep their ground.
    @Test func theKnockOutCoversEveryRulerLabelThePillTouches() {
        let mapping = FrameMapping(duration: 120, frameWidth: 10)
        let rules = TimelineRulerLabels(mapping: mapping, unit: .timecode, fps: 24)
        let pill = TimelinePlayheadGrab.pill(lineX: tickX(mapping, 30), label: rules.text(30), width: 720)
        let grounds = TimelinePlayheadGrab.grounds(pill: pill, rules: rules, scrollX: 0)
        let ground = grounds.reduce(CGRect.null) { $0.union($1) }
        let inset = Double(timelineInset)
        let labels = rules.placed(rules.frames(visibleX: 0...720))
        let touched = labels.filter { $0.minX + inset < Double(pill.maxX) && $0.maxX + inset > Double(pill.minX) }
        #expect(touched.contains { $0.maxX + inset > Double(pill.maxX) })
        for label in labels {
            let covered = Double(ground.minX) <= label.minX + inset && Double(ground.maxX) >= label.maxX + inset
            let clear = Double(ground.maxX) < label.minX + inset || Double(ground.minX) > label.maxX + inset
            #expect(touched.contains(label) ? covered : clear, "label \(label.text)")
        }
        #expect(ground.contains(pill.insetBy(dx: -TimelinePlayheadGrab.knockOut, dy: 0)))
        #expect(ground.minY >= 0 && ground.maxY <= SuiteSize.timelineRuler)
        // Beside the pill only the label's text band clears; the ticks under it stay.
        #expect(grounds.dropFirst().allSatisfy { $0.minY == 0 && $0.maxY < SuiteSize.timelineRuler })
    }

    /// A label that ends just before the pill keeps its ground: only labels
    /// the pill touches are knocked out, not every label near it.
    @Test func aLabelEndingBeforeThePillKeepsItsGround() {
        let mapping = FrameMapping(duration: 120, frameWidth: 10)
        let rules = TimelineRulerLabels(mapping: mapping, unit: .frames, fps: 24)
        guard let label = rules.placed(rules.frames(visibleX: 0...720)).first(where: { $0.frame == 30 }) else {
            Issue.record("no label at 30")
            return
        }
        let pill = CGRect(x: label.maxX + Double(timelineInset) + 1, y: 2, width: 30, height: SuiteSize.pill)
        #expect(TimelinePlayheadGrab.grounds(pill: pill, rules: rules, scrollX: 0).count == 1)
    }
}
