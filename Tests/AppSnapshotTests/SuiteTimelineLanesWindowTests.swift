// SuiteTimelineLanesWindowTests.swift: what a key drag costs the AppKit lanes
// in a real 1280 x 400 window (timeline packet, the TL-f quality row, line
// 487): SuiteTimelineKeyDragWindowTests' host, 300 lanes, 10,000 frames, keys
// every 12, 4 pt a frame, lane 5's key at 120 picked and dragged by 120 events
// over 600 pt. Spec: at most 0 lane bodies and at most 1 window body (the
// host's, on the commit), one move call per frame step summing to 150, one
// onEndKeyDrag; the step p95 the harness prints is the lane redraw time,
// reported and not judged. TL-20 writes it disabled; TL-22 enables it. The
// press is a window-activation click the host opts in to (#1746). Nested in
// BodyCountSuites: it reads global body counters. macOS only.
import AppKit
import SwiftUI
import Testing

@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct SuiteTimelineLanesWindowTests {
        @Test(.disabled("waits on TL-22"), .timeLimit(.minutes(2))) func aLaneDragRunsNoLaneBodies() async throws {
            let sent = LanesDragSent()
            let size = CGSize(width: 1280, height: 400)
            let w = RenderBudgetWindow(LanesDragHost(sent: sent).frame(width: size.width, height: size.height, alignment: .top), size: size)
            defer { w.close() }
            try await w.settle(600)

            // Lane 5's key at 120 in window points (y up): names column, divider, inset, 4 pt a frame; the
            // ruler, then five and a half lanes down.
            let box = w.host.convert(w.host.bounds, to: nil)
            let x = box.minX + SuiteSize.timelineLabelColumn + 1 + timelineInset + 120 * 4
            let y = box.maxY - (SuiteSize.timelineRuler + SuiteSize.timelineLane * 5.5)
            let lanesBefore = laneBodies()
            let step = try await w.measure("timeline lanes key drag, 120 samples", bodies: { LanesDragHost.bodyRuns }) {
                try await w.drag(from: CGPoint(x: x, y: y), by: CGVector(dx: 600, dy: 0))
            }
            let steps = sent.moves.count
            #expect(steps > 0 && steps <= 150, "\(steps) move calls for a 150-frame drag: \(step)")
            #expect(sent.moves.reduce(0, +) == 150, "the moves \(sent.moves) don't sum to 150")
            #expect(!sent.moves.contains(0), "a move call sent no frames: \(sent.moves)")
            #expect(sent.ends == 1, "onEndKeyDrag ran \(sent.ends) times")
            #expect((step.bodies ?? 0) <= 1, "the window ran \(step.bodies ?? 0) bodies for the drag: \(step)")
            if let before = lanesBefore, let after = laneBodies() {
                #expect(after - before <= 0, "lanes ran \(after - before) bodies for \(steps) steps: \(step)")
            }
        }

        private func laneBodies() -> Int? {
            #if DEBUG
            return TimelineLane<String>.bodyRuns
            #else
            return nil
            #endif
        }
    }
}

/// What the strip sent the host during the drag.
@MainActor private final class LanesDragSent { var moves: [Int] = []; var ends = 0 }

/// The strip on the sample, applying each move to its picked keys as a host does, counting its own bodies.
private struct LanesDragHost: View {
    let sent: LanesDragSent
    /// How many times the host's body ran: the window bodies the budget counts.
    @MainActor static var bodyRuns = 0
    @State private var tracks: [TimelineTrack<String>] = (0..<300).map { lane in
        TimelineTrack(
            id: "lane-\(lane)", name: "Lane \(lane)",
            keys: stride(from: 0, through: 10_000, by: 12).map { TimelineKey(frame: $0, shape: .linear) },
            pickedFrames: lane == 5 ? [120] : [])
    }
    @State private var playhead = 0

    var body: some View {
        let _ = Self.bodyRuns += 1
        TimelineStrip(
            tracks: tracks, duration: 10_000, frameWidth: 4, playhead: playhead,
            onScrub: { playhead = $0 },
            onMoveKeyframes: { delta in
                sent.moves.append(delta)
                tracks = tracks.map { Self.moving($0, by: delta) }
            },
            onEndKeyDrag: { sent.ends += 1 })
        .allowsWindowActivationEvents()  // every press here activates the window (#1746)
    }

    private static func moving(_ track: TimelineTrack<String>, by delta: Int) -> TimelineTrack<String> {
        guard !track.pickedFrames.isEmpty else { return track }
        let keys = track.keys.map { track.pickedFrames.contains($0.frame) ? TimelineKey(frame: $0.frame + delta, shape: $0.shape) : $0 }
        return TimelineTrack(
            id: track.id, name: track.name, keys: keys, spans: track.spans,
            pickedFrames: Set(track.pickedFrames.map { $0 + delta }), isSelected: track.isSelected)
    }
}
