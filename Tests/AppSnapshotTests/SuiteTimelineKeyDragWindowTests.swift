// SuiteTimelineKeyDragWindowTests.swift: what a key drag costs TimelineStrip
// in a real 1280 x 400 window (timeline packet, the real-window budgets): 300
// lanes, 10,000 frames, keys every 12, 4 pt a frame, a host keeping tracks and
// playhead in @State. Keys at 120 are picked on lanes 5 and 6; lane 5's takes
// 120 dragged events over 600 pt. Spec: lanes run at most 2 x (frame steps +
// 2) bodies (the counter sums every lane), one move call per step summing to
// 150, one onEndKeyDrag. TL-13 wrote it disabled; TL-14 enabled it. The test
// process is never the active app, so its press is a window-activation click,
// which a SwiftUI gesture drops unless it opts in (RenderBudgetHarness.swift):
// the host opts in, as the scrub window test's does (#1746), and the press is
// placed from the host's frame in window points. Nested in BodyCountSuites: it
// reads global body counters. macOS only.
import AppKit
import SwiftUI
import Testing

@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct SuiteTimelineKeyDragWindowTests {
        @Test(.timeLimit(.minutes(2))) func aKeyDragRedrawsOnlyItsLanes() async throws {
            let sent = KeyDragSent()
            let size = CGSize(width: 1280, height: 400)
            let w = RenderBudgetWindow(KeyDragHost(sent: sent).frame(width: size.width, height: size.height, alignment: .top), size: size)
            defer { w.close() }
            try await w.settle(600)

            // Lane 5's key at 120 in window points (y up), from the host's top left: names column, divider,
            // inset, then 4 pt a frame across; the ruler, then five and a half lanes down.
            let box = w.host.convert(w.host.bounds, to: nil)
            let x = box.minX + SuiteSize.timelineLabelColumn + 1 + timelineInset + 120 * 4
            let y = box.maxY - (SuiteSize.timelineRuler + SuiteSize.timelineLane * 5.5)
            let lanesBefore = laneBodies()
            let step = try await w.measure("timeline key drag, 120 samples", bodies: stripBodies) {
                try await w.drag(from: CGPoint(x: x, y: y), by: CGVector(dx: 600, dy: 0))
            }
            let steps = sent.moves.count
            #expect(steps > 0 && steps <= 150, "\(steps) move calls for a 150-frame drag: \(step)")
            #expect(sent.moves.reduce(0, +) == 150, "the moves \(sent.moves) don't sum to 150")
            #expect(!sent.moves.contains(0), "a move call sent no frames: \(sent.moves)")
            #expect(sent.ends == 1, "onEndKeyDrag ran \(sent.ends) times")
            if let before = lanesBefore, let after = laneBodies() {
                #expect(after - before <= 2 * (steps + 2), "lanes ran \(after - before) bodies for \(steps) steps: \(step)")
            }
        }

        private func laneBodies() -> Int? {
            #if DEBUG
            return TimelineLane<String>.bodyRuns
            #else
            return nil
            #endif
        }

        private func stripBodies() -> Int? {
            #if DEBUG
            return TimelineStrip<String>.bodyRuns
            #else
            return nil
            #endif
        }
    }
}

/// What the strip sent the host during the drag.
@MainActor private final class KeyDragSent {
    var moves: [Int] = []
    var ends = 0
}

/// The strip on the sample, applying each move to its picked keys as a host does.
private struct KeyDragHost: View {
    let sent: KeyDragSent
    @State private var tracks: [TimelineTrack<String>] = (0..<300).map { lane in
        TimelineTrack(
            id: "lane-\(lane)", name: "Lane \(lane)",
            keys: stride(from: 0, through: 10_000, by: 12).map { TimelineKey(frame: $0, shape: .linear) },
            pickedFrames: lane == 5 || lane == 6 ? [120] : [])
    }
    @State private var playhead = 0

    var body: some View {
        TimelineStrip(
            tracks: tracks, duration: 10_000, frameWidth: 4, playhead: playhead,
            onScrub: { playhead = $0 },
            onMoveKeyframes: { delta in
                sent.moves.append(delta)
                tracks = tracks.map { Self.moving($0, by: delta) }
            },
            onEndKeyDrag: { sent.ends += 1 })
        // Every press here activates the window; a hand's press in the active window needs no opt-in.
        .allowsWindowActivationEvents()
    }

    private static func moving(_ track: TimelineTrack<String>, by delta: Int) -> TimelineTrack<String> {
        guard !track.pickedFrames.isEmpty else { return track }
        let keys = track.keys.map { track.pickedFrames.contains($0.frame) ? TimelineKey(frame: $0.frame + delta, shape: $0.shape) : $0 }
        return TimelineTrack(
            id: track.id, name: track.name, keys: keys, spans: track.spans,
            pickedFrames: Set(track.pickedFrames.map { $0 + delta }), isSelected: track.isSelected)
    }
}
