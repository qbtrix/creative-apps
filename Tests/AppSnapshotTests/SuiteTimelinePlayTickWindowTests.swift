// SuiteTimelinePlayTickWindowTests.swift: what a playback tick costs the real
// strip (#5804). SuiteTimelineScrubWindowTests' sample (TimelineStrip on 300
// lanes, 10,000 frames, keys every 12, 4 pt a frame, in a 1280 x 400
// borderless window far off screen), with the playhead held by a clock the
// test advances one frame per 1/120 s, as a playback driver does: no pointer
// input at all. Spec: the playhead's body runs once per frame shown (it
// follows playback, never parks), and no lane body and no lane input body runs,
// since a lane's keys and rows didn't change. Counting starts once no body has
// run for 300 ms. The expectations read this window's own BodyTally. macOS only.
import AppKit
import SwiftUI
import Testing

@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct SuiteTimelinePlayTickWindowTests {
        @Test(.timeLimit(.minutes(2))) func aPlayTickRedrawsOnlyThePlayhead() async throws {
            let clock = PlayTickClock()
            let tally = BodyTally.forNewWindow()
            let host = CountingHostingView(rootView: PlayTickHost(clock: clock, tally: tally))
            let frame = CGRect(x: 0, y: 0, width: 1280, height: 400)
            host.frame = frame
            let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
            window.orderFrontRegardless()
            defer { window.close() }
            try await Task.sleep(for: .milliseconds(500))
            let settledOK = try await settled(tally)
            let before = own(tally)
            let ticks = 120
            let wall = ContinuousClock(), began = wall.now
            for i in 1...ticks {
                clock.frame = i
                try await Task.sleep(until: began + .microseconds(8_333 * i), clock: wall)
                host.layoutSubtreeIfNeeded()
                window.displayIfNeeded()
            }
            try await Task.sleep(for: .milliseconds(150))
            let runs = zip(own(tally), before).map { $0 - $1 }
            let report = "PLAY-TICK lanes=300 ticks=\(ticks) bodies lane/laneInput/playhead/strip=\(runs) settled=\(settledOK)"
            print(report)
            #expect(runs[0] == 0, "a lane redrew on a play tick: \(report)")
            #expect(runs[1] == 0, "a lane's input re-ran on a play tick: \(report)")
            #expect(runs[2] >= ticks - 2, "the playhead didn't follow every frame: \(report)")
            #expect(runs[2] <= ticks + 2, "the playhead ran more than once per frame: \(report)")
            #expect(runs[3] <= ticks + 2, "the strip ran more than once per frame: \(report)")
        }

        /// Whether no counted body of this window ran for 300 ms (waits 10 s at most).
        private func settled(_ tally: BodyTally) async throws -> Bool {
            var last = own(tally), idle = 0
            for _ in 0..<100 {
                try await Task.sleep(for: .milliseconds(100))
                let now = own(tally)
                if now == last { idle += 1 } else { last = now; idle = 0 }
                if idle == 3 { return true }
            }
            return false
        }

        /// This window's lane, lane input, playhead and strip body runs so far; zeros in release.
        private func own(_ tally: BodyTally) -> [Int] {
            [TimelineLaneBodies.self, TimelineLaneInputBodies.self, TimelinePlayhead.self, TimelineStripBodies.self]
                .map(tally.runs(of:))
        }
    }
}

/// The playing frame, advanced by the test as a playback driver would.
@MainActor @Observable private final class PlayTickClock {
    var frame = 0
}

/// The strip over the budget sample, its playhead read from the clock.
private struct PlayTickHost: View {
    static let duration = 10_000
    static let tracks = (0..<300).map { lane in
        TimelineTrack(id: lane, name: "Lane \(lane + 1)", keys: stride(from: lane % 12, through: duration, by: 12)
            .map { TimelineKey(frame: $0, shape: .linear) })
    }
    let clock: PlayTickClock
    let tally: BodyTally

    var body: some View {
        TimelineStrip(tracks: Self.tracks, duration: Self.duration, frameWidth: 4, playhead: clock.frame)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .environment(\.bodyTally, tally)
    }
}
