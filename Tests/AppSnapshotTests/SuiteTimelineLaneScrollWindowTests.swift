// SuiteTimelineLaneScrollWindowTests.swift: a scroll builds the lane rows it
// brings into view (#6116). TimelineLaneRows builds only the rows the strip's
// vertical scroll shows (`shown`, TimelineStrip.lanesShown), with clear space
// for the rest. The test hosts TimelineLaneRows in a borderless window far off
// screen, moves `shown` from the top rows to rows 100 to 105, as a scroll does,
// and expects new lane bodies: rows that were never built before. That `shown`
// is part of the rows' `==` is TimelineStripLayoutTests'
// `aScrollIsNeverAnEqualLaneRowsValue`: in this window SwiftUI re-ran the body
// on a changed `shown` even with `==` returning true, so this test alone does
// not catch a dropped `shown`. Counts read this window's own BodyTally. macOS only.
import AppKit
import SwiftUI
import Testing

@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct SuiteTimelineLaneScrollWindowTests {
        @Test(.timeLimit(.minutes(1))) func aScrollBuildsTheLowerRows() async throws {
            let scroll = LaneScroll()
            let tally = BodyTally.forNewWindow()
            let host = NSHostingView(rootView: LaneScrollHost(scroll: scroll, tally: tally))
            let frame = CGRect(x: 0, y: 0, width: 800, height: 400)
            host.frame = frame
            let window = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentView = host
            window.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
            window.orderFrontRegardless()
            defer { window.close() }
            try await Task.sleep(for: .milliseconds(300))
            host.layoutSubtreeIfNeeded()
            let top = tally.runs(of: TimelineLaneBodies.self)
            #expect(top >= scroll.shown.count, "the first screen's lanes weren't built: \(top)")

            scroll.shown = 100..<106
            try await Task.sleep(for: .milliseconds(300))
            host.layoutSubtreeIfNeeded()
            let built = tally.runs(of: TimelineLaneBodies.self) - top
            #expect(built >= scroll.shown.count, "a scroll to rows 100-105 built \(built) lanes; they stay blank")
        }
    }
}

/// The rows shown, moved by the test as the strip's vertical scroll would.
@MainActor @Observable private final class LaneScroll {
    var shown = 0..<6
}

/// TimelineLaneRows over 300 keyed tracks, its rows shown read from the scroll.
private struct LaneScrollHost: View {
    static let tracks = (0..<300).map { lane in
        TimelineTrack(id: lane, name: "Lane \(lane + 1)", keys: [TimelineKey(frame: lane % 12, shape: .linear)])
    }
    let scroll: LaneScroll
    let tally: BodyTally
    @State private var context = TimelineLaneContext<Int>()

    var body: some View {
        ScrollView(.vertical) {
            TimelineLaneRows(
                tracks: Self.tracks, shown: scroll.shown, mapping: FrameMapping(duration: 100, frameWidth: 4),
                context: context, width: 400
            ).equatable()
        }
        .environment(\.bodyTally, tally)
    }
}
