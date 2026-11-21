// RenderBudgetTimelineSpanTests.swift (timeline-keys TK-4 and TK-3, Quality
// tests, packet docs/blueprints/suiteui/features/timeline-keys.md).
// `slideDragInThreeBodies`: a strip whose host applies each slide to its one
// bar (24...71 of 100, no keys), dragged by its body 120 samples left: at
// most 3 window bodies (the lane draws each step on its own layer, TL-22) and
// one slide on release. It hosts its own strip because Halo's bars can't
// slide until TK-6 builds `layer.slide` (the strip then starts no slide);
// TK-9 points it at Halo's window. `flareKeyClick`: on Flare's `bounce` with
// Ball selected, one click on FILL's key button keys the fill at the playhead
// in at most 2 window bodies. TimelineSpanDragTests holds the rule with no
// window: a body drag reports one delta per frame crossed and never trims, an
// end drag still trims and never slides, Shift lands an edge on the playhead,
// on a lane the host hears one slide on release, and a strip that can't edit
// spans neither slides nor trims a bar: the press selects its track. macOS only.
#if canImport(AppKit)
import AppKit
import FlareCore
import FlareModel
import SuiteKernel
import SwiftUI
import Testing

@testable import FlareApp
@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetTimelineSpanTests {
        @Test(.timeLimit(.minutes(2))) func slideDragInThreeBodies() async throws {
            SpanSlideBudgetWindow.slides = []
            let w = RenderBudgetWindow(SpanSlideBudgetWindow())
            defer { w.close() }
            let bodies = { () -> Int? in
                #if DEBUG
                return SpanSlideBudgetWindow.bodyRuns
                #else
                return nil
                #endif
            }
            try await w.settle(500)
            try await w.settle(untilStable: bodies)
            let lane = try #require(await w.element("budget.timeline.lane.title"), "no lane for Title")
            // About frame 47 of 100: inside the bar, far from its ends and the playhead at 0.
            let start = CGPoint(x: lane.minX + lane.width * 0.47, y: lane.midY)
            let step = try await w.measure("bar slide, 120 samples", bodies: bodies) {
                try await w.drag(from: start, by: CGVector(dx: -120, dy: 0))
            }
            print("BAR-SLIDE \(step)")
            #expect(step.steps >= 120, "the drag sent \(step.steps) steps")
            #expect(SpanSlideBudgetWindow.slides.count == 1 && (SpanSlideBudgetWindow.slides.first ?? 0) < 0,
                    "the release sent \(SpanSlideBudgetWindow.slides), not one slide left")
            expectBodies(step, atMost: 3, target: 3)
        }

        @Test(.timeLimit(.minutes(2))) func flareKeyClick() async throws {
            var model = FlareWorkspace(services: .built)
            model.finishOpen(.success(try #require(FlareFixtures.named("bounce"))), named: "bounce.flare")
            model.selectLayer("ball")
            #expect(!model.canUndo && model.keyState(.fill) == .notAnimated, "Ball's fill starts keyed or edited")
            #expect(model.paintKeyHelp(.fill) == nil, "FILL's key button is off: \(model.paintKeyHelp(.fill) ?? "")")
            let w = RenderBudgetWindow(FlareWindow(model: model))
            defer { w.close() }
            let bodies = { () -> Int? in
                #if DEBUG
                return FlareWindow.bodyRuns
                #else
                return nil
                #endif
            }
            try await w.settle(500)
            try await w.settle(untilStable: bodies)
            let key = try #require(await w.element("flare.inspector.key.fill"), "FILL shows no key button")
            let step = try await w.measure("flare FILL key click", bodies: bodies) {
                try await w.ticks(1) { _ in w.click(at: CGPoint(x: key.midX, y: key.midY)) }
            }
            try await w.settle(100)
            #if DEBUG
            // One key leaves the fill reading not animated (FlareColorKeysTests), so the undo step is the proof.
            #expect(FlareWindow.shownModel?.undoName == "Add Keyframe", "the click keyed nothing: \(step)")
            #endif
            expectBodies(step, atMost: 2, target: 2)
        }
    }
}

/// The counted window: one strip whose host slides its one bar by each slide it hears.
private struct SpanSlideBudgetWindow: View, BodyCounted {
    #if DEBUG
    @Environment(\.bodyTally) private var bodyTally
    #endif
    // view-static: main-actor
    static var slides: [Int] = []
    @State private var span = 24...71

    var body: some View {
        #if DEBUG
        let _ = bodyTally.ran(Self.self)
        #endif
        TimelineStrip(
            tracks: [TimelineTrack(id: "title", name: "Title", keys: [], spans: [span])],
            duration: 100, frameWidth: 8, playhead: 0,
            onSlide: { _, by in
                Self.slides.append(by)
                span = (span.lowerBound + by)...(span.upperBound + by)
            })
            .environment(\.timelineIdentifierPrefix, "budget.timeline")
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}

@MainActor @Suite struct TimelineSpanDragTests {
    private static let mapping = FrameMapping(duration: 400, frameWidth: 4)
    private static let track = TimelineTrack(
        id: "a", name: "A", keys: [150].map { TimelineKey(frame: $0, shape: .linear) }, spans: [100...200])

    /// Every slide, trim and end the host heard, in order.
    @MainActor private final class Log {
        var calls: [String] = []
        var editsSpans = true
        var actions: TimelineLaneActions<String> {
            var actions = TimelineLaneActions<String>(
                onSelectKeyframe: { _, _ in }, onSelectTrack: { self.calls.append("select \($0)") },
                onPickKeyframe: { _, _, _ in },
                onMoveKeyframes: { self.calls.append("move \($0)") }, onEndKeyDrag: { self.calls.append("end") },
                onTrim: { self.calls.append("trim \($0) \($1.rawValue) \($2)") }, onEndTrim: { self.calls.append("endTrim") })
            actions.onSlide = { self.calls.append("slide \($0) \($1)") }
            actions.editsSpans = editsSpans
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

    @Test func withoutSpanEditsABarDragNeitherSlidesNorTrims() {
        for (frame, part) in [(170, "body"), (200, "end")] {
            let log = Log()
            log.editsSpans = false
            let (view, end) = dragged(log, from: frame, by: 40)
            #expect(view.lanes.first?.spans == [100...200], "a drag on the bar's \(part) moved it")
            view.release(at: end)
            #expect(log.calls == ["select a"], "a drag on the bar's \(part) sent \(log.calls)")
        }
    }

    /// A lane view whose pointer reports to `log`, pressed at `frame` and dragged `dx` points.
    private func dragged(_ log: Log, from frame: Int, by dx: Int) -> (TimelineLanesView, CGPoint) {
        let view = TimelineLanesView(frame: NSRect(x: 0, y: 0, width: 1_800, height: SuiteSize.timelineLane))
        let pointer = TimelineLanePointer<String>()
        pointer.configure(
            track: Self.track, mapping: Self.mapping, context: TimelineLaneContext(playhead: 0, actions: log.actions),
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
