// RenderBudgetTimelineSpanTests.swift (timeline-keys TK-4, Quality tests,
// packet docs/blueprints/suiteui/features/timeline-keys.md): a span's body
// drag slides it. `slideDragInThreeBodies`: on Halo's `three-layers`, Title's
// bar (24...71, no keys) is dragged by its body 120 samples left: at most 3
// window bodies (the lane draws each step on its own layer, TL-22; the
// release sends one slide). TimelineSpanDragTests holds the rule with no
// window: a body drag reports one delta per frame crossed and never trims, an
// end drag still trims and never slides, Shift lands an edge on the playhead,
// and on a lane the host hears one slide on release. macOS only.
#if canImport(AppKit)
import AppKit
import HaloModel
import SuiteKernel
import SwiftUI
import Testing

@testable import HaloApp
@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetTimelineSpanTests {
        static let title = "comp-1-layer-4"

        @Test(.timeLimit(.minutes(2))) func slideDragInThreeBodies() async throws {
            let project = HaloLaunch(arguments: ["Halo", "-HaloFixture", "three-layers"]).project()
            let w = RenderBudgetWindow(HaloWindow(model: project))
            defer { w.close() }
            try await w.settle(500)
            try await w.settle(untilStable: HaloWindowPlaybackTests.windowBodies)
            let lane = try #require(await w.element("halo.timeline.lane.\(Self.title)"), "no lane for Title")
            // About frame 47 of 71: inside Title's bar, far from its ends and the playhead at 0.
            let start = CGPoint(x: lane.minX + lane.width * 0.66, y: lane.midY)
            let step = try await w.measure("halo bar slide, 120 samples", bodies: HaloWindowPlaybackTests.windowBodies) {
                try await w.drag(from: start, by: CGVector(dx: -120, dy: 0))
            }
            print("BAR-SLIDE \(step)")
            #expect(step.steps >= 120, "the drag sent \(step.steps) steps")
            expectBodies(step, atMost: 3, target: 3)
        }
    }
}

@MainActor @Suite struct TimelineSpanDragTests {
    private static let mapping = FrameMapping(duration: 400, frameWidth: 4)
    private static let track = TimelineTrack(
        id: "a", name: "A", keys: [150].map { TimelineKey(frame: $0, shape: .linear) }, spans: [100...200])

    /// Every slide, trim and end the host heard, in order.
    @MainActor private final class Log {
        var calls: [String] = []
        var actions: TimelineLaneActions<String> {
            var actions = TimelineLaneActions<String>(
                onSelectKeyframe: { _, _ in }, onSelectTrack: { self.calls.append("select \($0)") },
                onPickKeyframe: { _, _, _ in },
                onMoveKeyframes: { self.calls.append("move \($0)") }, onEndKeyDrag: { self.calls.append("end") },
                onTrim: { self.calls.append("trim \($0) \($1.rawValue) \($2)") }, onEndTrim: { self.calls.append("endTrim") })
            actions.onSlide = { self.calls.append("slide \($0) \($1)") }
            return actions
        }
    }

    @Test func aBodyDragReportsOneDeltaPerFrameCrossed() {
        let log = Log()
        var slide = TimelineSlideDrag(span: 100...200, playhead: 0, mapping: Self.mapping, snaps: false)
        for dx in 1...12 { _ = slide.move(dx: Double(dx), id: "a", actions: log.actions) }
        #expect(log.calls == ["slide a 1", "slide a 1", "slide a 1"], "4 pt a frame: 12 pt crosses 3")
        #expect(!log.calls.contains { $0.hasPrefix("trim") }, "a body drag trimmed")
    }

    @Test func aSlideStaysInsideTheDuration() {
        let slide = TimelineSlideDrag(span: 100...200, playhead: 0, mapping: Self.mapping, snaps: false)
        #expect(slide.total(dx: -1_000) == -100)
        #expect(slide.total(dx: 1_000) == 200)
    }

    @Test func shiftLandsAnEdgeOnThePlayhead() {
        let free = TimelineSlideDrag(span: 100...200, playhead: 251, mapping: Self.mapping, snaps: false)
        let snapping = TimelineSlideDrag(span: 100...200, playhead: 251, mapping: Self.mapping, snaps: true)
        #expect(free.total(dx: 200) == 50)
        #expect(snapping.total(dx: 200) == 51, "the end edge lands on the playhead")
    }

    @Test func onALaneABodyDragSlidesOnceAndAnEndDragStillTrims() {
        let body = Log()
        let (bodyView, bodyEnd) = dragged(body, from: 150 + 20, by: 40)
        #expect(body.calls.isEmpty, "a sample must not reach the host")
        #expect(bodyView.lanes.first?.spans == [110...210], "the view draws the slide itself")
        #expect(bodyView.lanes.first?.keys.map(\.frame) == [160], "the keys move with the bar")
        bodyView.release(at: bodyEnd)
        #expect(body.calls == ["slide a 10"])

        let end = Log()
        let (endView, endEnd) = dragged(end, from: 200, by: 40)
        endView.release(at: endEnd)
        #expect(end.calls == ["trim a end 210", "endTrim"], "an end drag slid")
    }

    @Test func aBodyClickStillSelectsTheTrack() {
        let log = Log()
        let (view, end) = dragged(log, from: 120, by: 1)
        view.release(at: CGPoint(x: end.x - 1, y: end.y))
        #expect(log.calls == ["select a"])
    }

    /// A lane view whose pointer reports to `log`, pressed at `frame` and dragged `dx` points.
    private func dragged(_ log: Log, from frame: Int, by dx: Int) -> (TimelineLanesView, CGPoint) {
        let view = TimelineLanesView(frame: NSRect(x: 0, y: 0, width: 1_800, height: SuiteSize.timelineLane))
        let pointer = TimelineLanePointer<String>()
        pointer.configure(
            track: Self.track, mapping: Self.mapping, playhead: 0, actions: log.actions,
            extras: TimelineLanePointerExtras(focus: nil, pill: .constant(nil), mark: nil))
        view.pointer = pointer
        view.update([TimelineLaneDrawing(Self.track, mapping: Self.mapping)])
        let start = CGPoint(x: tickX(Self.mapping, frame), y: SuiteSize.timelineLane / 2)
        view.press(at: start, flags: [])
        for sample in 1...dx { view.drag(to: CGPoint(x: start.x + CGFloat(sample), y: start.y)) }
        return (view, CGPoint(x: start.x + CGFloat(dx), y: start.y))
    }
}
#endif
