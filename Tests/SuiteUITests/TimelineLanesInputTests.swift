// TimelineLanesInputTests.swift: TL-22. A lane's pointer on TimelineLanesView draws each
// step itself and tells the host once on release; Escape sends nothing. macOS only.
import AppKit
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor @Suite struct TimelineLanesInputTests {
    private static let mapping = FrameMapping(duration: 400, frameWidth: 4)
    private static let track = TimelineTrack(
        id: "a", name: "A", keys: [40, 100].map { TimelineKey(frame: $0, shape: .linear) },
        spans: [100...200], pickedFrames: [40])

    /// Every move, trim and end the host heard, in order.
    @MainActor private final class Log {
        var calls: [String] = []
        var actions: TimelineLaneActions<String> {
            TimelineLaneActions(
                onMoveKeyframes: { self.calls.append("move \($0)") }, onEndKeyDrag: { self.calls.append("end") },
                onTrim: { self.calls.append("trim \($0) \($1.rawValue) \($2)") }, onEndTrim: { self.calls.append("endTrim") })
        }
    }

    /// A lane view whose pointer reports to `log`, pressed at `frame` and dragged `dx` points.
    private func dragged(_ log: Log, from frame: Int, by dx: Int) -> (TimelineLanesView, TimelineLanePointer<String>, CGPoint) {
        let view = TimelineLanesView(frame: NSRect(x: 0, y: 0, width: 1_600, height: SuiteSize.timelineLane))
        let pointer = TimelineLanePointer<String>()
        pointer.configure(
            track: Self.track, mapping: Self.mapping, playhead: 0, actions: log.actions,
            extras: TimelineLanePointerExtras(focus: nil, pill: .constant(nil), mark: nil))
        view.pointer = pointer
        view.update([TimelineLaneDrawing(Self.track, mapping: Self.mapping)])
        let start = point(frame)
        view.press(at: start, flags: [])
        for sample in 1...dx { view.drag(to: CGPoint(x: start.x + CGFloat(sample), y: start.y)) }
        return (view, pointer, CGPoint(x: start.x + CGFloat(dx), y: start.y))
    }

    private func point(_ frame: Int) -> CGPoint { CGPoint(x: tickX(Self.mapping, frame), y: SuiteSize.timelineLane / 2) }

    @Test func aKeyDragTellsTheHostOnceAndRunsNoLaneBody() {
        let log = Log()
        #if DEBUG
        let before = TimelineLane<String>.bodyRuns
        #endif
        let (view, _, end) = dragged(log, from: 40, by: 120)
        #expect(log.calls.isEmpty, "a sample must not reach the host")
        #expect(view.lanes.first?.keys.map(\.frame) == [70, 100], "the view draws the step itself")
        #if DEBUG
        #expect(TimelineLane<String>.bodyRuns == before)
        #endif
        view.release(at: end)
        #expect(log.calls == ["move 30", "end"])
    }

    @Test func aTrimTellsTheHostOnce() {
        let log = Log()
        let (view, _, end) = dragged(log, from: 200, by: 40)
        #expect(log.calls.isEmpty)
        #expect(view.lanes.first?.spans == [100...210])
        view.release(at: end)
        #expect(log.calls == ["trim a end 210", "endTrim"])
    }

    @Test func escapeDropsTheDragAndSendsNothing() {
        let log = Log()
        let (view, pointer, end) = dragged(log, from: 40, by: 40)
        let cancelled = pointer.cancel()
        #expect(cancelled)
        view.release(at: end)
        #expect(log.calls.isEmpty, "Escape must keep the keys where they were")
    }

    @Test func thePlayheadBandIsLeftToThePlayhead() {
        let (view, _, _) = dragged(Log(), from: 300, by: 1)
        #expect(!view.takesPress(at: point(0)))
        #expect(view.takesPress(at: point(40)) && view.takesPress(at: point(300)))
    }
}
