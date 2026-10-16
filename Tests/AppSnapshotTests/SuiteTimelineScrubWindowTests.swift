// SuiteTimelineScrubWindowTests.swift: what a ruler scrub costs the real
// timeline strip (timeline packet, The real-window budgets; lesson 153). It
// hosts TimelineStrip itself, in a small host that keeps the playhead in
// @State and applies each onScrub as Halo and Flare do, in a 1280 x 400
// borderless window ordered in far off every screen, as PhotoWindowStrokeTests
// hosts Photo's window (with its CountingHostingView). Sample: 300 lanes,
// 10,000 frames, keys every 12 frames, 4 pt per frame. It sends a mouse-down
// on the ruler, 120 dragged events at 120 Hz over 600 pt and a mouse-up, and
// reads the debug bodyRuns counters. Spec: no lane and no ruler body runs,
// the playhead and the strip each run at most frames crossed + 2, and onScrub
// is called once per frame crossed, never with the same frame twice in a row.
// Layout passes are reported, not judged. TL-5 writes it disabled; TL-8 turns
// it on. macOS only.
#if canImport(AppKit)
import AppKit
import SwiftUI
import Testing

@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct SuiteTimelineScrubWindowTests {
        @Test(.disabled("waits on TL-8"), .timeLimit(.minutes(2))) func aScrubRedrawsOnlyThePlayhead() async throws {
            let scrubs = ScrubLog()
            let host = CountingHostingView(rootView: ScrubHost(log: scrubs))
            let frame = CGRect(x: 0, y: 0, width: 1280, height: 400)
            host.frame = frame
            let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
            window.orderFrontRegardless()
            defer { window.close() }
            try await Task.sleep(for: .milliseconds(500))

            // The ruler runs along the top of the strip, right of the names column (window y is up).
            let start = CGPoint(x: SuiteSize.timelineLabelColumn + 40, y: frame.height - SuiteSize.timelineRuler / 2)
            let before = (bodies(), host.layouts)
            send(.leftMouseDown, at: start, to: window)
            var xs = [start.x]
            let clock = ContinuousClock()
            let began = clock.now
            for i in 1...120 {
                try await Task.sleep(until: began + .microseconds(8_333 * i), clock: clock)
                let x = start.x + 5 * Double(i)
                xs.append(x)
                send(.leftMouseDragged, at: CGPoint(x: x, y: start.y), to: window)
            }
            try await Task.sleep(for: .milliseconds(150))
            let after = (bodies(), host.layouts)
            send(.leftMouseUp, at: CGPoint(x: start.x + 600, y: start.y), to: window)

            // Frames crossed, from the pointer's x anchored at the first frame the strip sent.
            let first = try #require(scrubs.frames.first, "the ruler press sent no frame")
            let mapping = FrameMapping(duration: ScrubHost.duration, frameWidth: ScrubHost.frameWidth)
            let origin = start.x - mapping.x(forFrame: first)
            let visited = [0] + xs.map { mapping.frame(atX: $0 - origin) }
            let crossed = zip(visited, visited.dropFirst()).filter { $0 != $1 }.count
            let runs = zip(after.0, before.0).map { $0 - $1 }
            let report = "SCRUB-WINDOW lanes=300 frames=10000 crossed=\(crossed) scrubs=\(scrubs.frames.count) "
                + "bodies lane/ruler/playhead/strip=\(runs) layouts=\(after.1 - before.1)"
            print(report)

            #expect(runs[0] == 0, "a lane redrew during the scrub: \(report)")
            #expect(runs[1] == 0, "the ruler redrew during the scrub: \(report)")
            #expect(runs[2] <= crossed + 2, "the playhead ran more than once per frame: \(report)")
            #expect(runs[3] <= crossed + 2, "the strip ran more than once per frame: \(report)")
            #expect(scrubs.frames.count == crossed, "onScrub calls aren't one per frame crossed: \(report)")
            #expect(zip(scrubs.frames, scrubs.frames.dropFirst()).allSatisfy { $0 != $1 }, "a frame was sent twice: \(report)")
        }

        /// Lane, ruler, playhead and strip body runs so far; zeros in release, which has no counters.
        private func bodies() -> [Int] {
            #if DEBUG
            return [TimelineLane<Int>.bodyRuns, TimelineRuler.bodyRuns, TimelinePlayhead.bodyRuns, TimelineStrip<Int>.bodyRuns]
            #else
            return [0, 0, 0, 0]
            #endif
        }

        private func send(_ kind: NSEvent.EventType, at point: CGPoint, to window: NSWindow) {
            guard let event = NSEvent.mouseEvent(
                with: kind, location: point, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)
            else {
                Issue.record("no \(kind) event")
                return
            }
            window.sendEvent(event)
        }
    }
}

/// Every frame onScrub was called with, in order.
@MainActor private final class ScrubLog {
    var frames: [Int] = []
}

/// The strip over the budget sample, holding the playhead as a host does.
private struct ScrubHost: View {
    static let duration = 10_000
    static let frameWidth = 4.0
    static let tracks = (0..<300).map { lane in
        TimelineTrack(id: lane, name: "Lane \(lane + 1)", keys: stride(from: lane % 12, through: duration, by: 12)
            .map { TimelineKey(frame: $0, shape: .linear) })
    }
    let log: ScrubLog
    @State private var playhead = 0

    var body: some View {
        TimelineStrip(
            tracks: Self.tracks, duration: Self.duration, frameWidth: CGFloat(Self.frameWidth), playhead: playhead,
            onScrub: { frame in
                log.frames.append(frame)
                playhead = frame
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
#endif
