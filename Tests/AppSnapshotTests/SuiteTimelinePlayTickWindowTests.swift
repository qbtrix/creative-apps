// SuiteTimelinePlayTickWindowTests.swift: what a playback tick costs the real
// strip (#5804). SuiteTimelineScrubWindowTests' sample (TimelineStrip on 300
// lanes, 10,000 frames, keys every 12, 4 pt a frame, in a 1280 x 400
// borderless window far off screen), with the playhead held by a clock the
// test advances one frame per 1/120 s, as a playback driver does: no pointer
// input at all. Spec: the playhead's body runs once per frame shown (it
// follows playback, never parks), and no lane body and no lane input body runs,
// since a lane's keys and rows didn't change. Counting starts once no body has
// run for 300 ms. The expectations read this window's own BodyTally.
//
// The first test lets SwiftUI flush each frame on its own run-loop observer,
// then lays out. The second lays the window out right after the frame change,
// before SwiftUI's flush, which is the order a display-link tick followed by
// AppKit's layout gets, and the order every frame got in the gate's heavy
// pass once a Photo render saturated the process. In that order the hosting
// view flushes the pending transaction from its layout, geometry goes first,
// and the lane stack measured each row by pushing its element into the row,
// which skipped the row's `==`: every lane and lane input ran on every frame
// (36,000 bodies in 120 frames) while the first test read 0. TimelineLaneRows'
// one `.equatable()` keeps the ForEach from re-evaluating at all, and both
// tests also count its body, which must not run on a frame change: that holds
// in either order and under any load, where the lane counts alone go green
// whenever the process is quick enough to flush first. macOS only.
import AppKit
import SwiftUI
import Testing

@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct SuiteTimelinePlayTickWindowTests {
        @Test(.timeLimit(.minutes(2))) func aPlayTickRedrawsOnlyThePlayhead() async throws {
            try await PlayTick.measure(in: "SwiftUI's flush, then layout")
        }

        @Test(.timeLimit(.minutes(2))) func aPlayTickRedrawsOnlyThePlayheadWhenLayoutRunsFirst() async throws {
            try await PlayTick.measure(in: "layout before SwiftUI's flush", layoutFirst: true)
        }
    }
}

/// The play-tick measurement: opens the sample window, settles, advances the playhead 120 frames at 120 Hz
/// and asserts on the lane, lane input, playhead and strip body counts of that window alone.
@MainActor enum PlayTick {
    static let ticks = 120

    /// Runs the measurement and asserts the spec; `order` names the order the counts are read in. With
    /// `layoutFirst` the window lays out right after each frame change, before SwiftUI's own flush.
    static func measure(in order: String, layoutFirst: Bool = false, sourceLocation: SourceLocation = #_sourceLocation) async throws {
        let (runs, settledOK) = try await run(layoutFirst: layoutFirst)
        let report = "PLAY-TICK lanes=300 ticks=\(ticks) bodies lane/laneInput/playhead/strip/laneRows=\(runs) settled=\(settledOK) with \(order)"
        print(report)
        #expect(runs[0] == 0, "a lane redrew on a play tick: \(report)", sourceLocation: sourceLocation)
        #expect(runs[1] == 0, "a lane's input re-ran on a play tick: \(report)", sourceLocation: sourceLocation)
        #expect(runs[2] >= ticks - 2, "the playhead didn't follow every frame: \(report)", sourceLocation: sourceLocation)
        #expect(runs[2] <= ticks + 2, "the playhead ran more than once per frame: \(report)", sourceLocation: sourceLocation)
        #expect(runs[3] <= ticks + 2, "the strip ran more than once per frame: \(report)", sourceLocation: sourceLocation)
        #expect(runs[4] == 0, "the lanes' ForEach was re-evaluated on a play tick: \(report)", sourceLocation: sourceLocation)
    }

    /// The lane, lane input, playhead, strip and lane rows body runs over `ticks` frames, and whether the window settled first.
    static func run(layoutFirst: Bool) async throws -> (runs: [Int], settled: Bool) {
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
        let wall = ContinuousClock(), began = wall.now
        for i in 1...ticks {
            clock.frame = i
            if layoutFirst { layOut(host, window) }
            try await Task.sleep(until: began + .microseconds(8_333 * i), clock: wall)
            if !layoutFirst { layOut(host, window) }
        }
        try await Task.sleep(for: .milliseconds(150))
        return (zip(own(tally), before).map { $0 - $1 }, settledOK)
    }

    private static func layOut(_ host: NSView, _ window: NSWindow) {
        host.layoutSubtreeIfNeeded()
        window.displayIfNeeded()
    }

    /// Whether no counted body of this window ran for 300 ms (waits 10 s at most).
    private static func settled(_ tally: BodyTally) async throws -> Bool {
        var last = own(tally), idle = 0
        for _ in 0..<100 {
            try await Task.sleep(for: .milliseconds(100))
            let now = own(tally)
            if now == last { idle += 1 } else { last = now; idle = 0 }
            if idle == 3 { return true }
        }
        return false
    }

    /// This window's lane, lane input, playhead, strip and lane rows body runs so far; zeros in release.
    private static func own(_ tally: BodyTally) -> [Int] {
        [TimelineLaneBodies.self, TimelineLaneInputBodies.self, TimelinePlayhead.self, TimelineStripBodies.self,
         TimelineLaneRowsBodies.self].map(tally.runs(of:))
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
