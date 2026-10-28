// BodyTallyWindowTests.swift: a view's `bodyRuns` reads the running test's
// windows, never another suite's window in the same test process (factory
// lesson 345). The test's window hosts a TimelinePlayhead; a neighbour window,
// opened from a detached task as a parallel suite's would be, redraws its own
// playhead 20 times; the test's count must not move. A redraw of the test's
// own window must still count, so a zero can't pass by counting nothing. A
// read before the test opens its window is 0, never the process's count, so a
// delta across the open can't go negative. macOS only.
#if canImport(AppKit)
import AppKit
import SuiteKernel
import SwiftUI
import Testing

@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct BodyTallyWindowTests {
        @Test(.timeLimit(.minutes(1))) func aNeighbourWindowsBodiesNeverCountInTheWindowUnderTest() async throws {
            #if DEBUG
            let opened = TimelinePlayhead.bodyRuns
            let w = RenderBudgetWindow(Self.playhead(at: 0))
            defer { w.close() }
            try await w.settle(untilStable: { TimelinePlayhead.bodyRuns })
            #expect(opened == 0, "before its window opened the test read \(opened) runs, not 0")
            #expect(TimelinePlayhead.bodyRuns >= 1, "opening the test's window counted no run")
            // Another suite's window: opened outside this test's task, as a suite running alongside opens its own.
            let neighbour = await Task.detached { @MainActor in RenderBudgetWindow(Self.playhead(at: 0)) }.value
            defer { neighbour.close() }
            try await neighbour.settle(100)
            let before = TimelinePlayhead.bodyRuns
            for frame in 1...20 { Self.show(Self.playhead(at: frame), in: neighbour) }
            try await w.settle(100)
            let neighbourRuns = TimelinePlayhead.bodyRuns - before
            #expect(neighbourRuns == 0, "the neighbour window's 20 redraws counted \(neighbourRuns) runs in this test")
            Self.show(Self.playhead(at: 5), in: w)
            try await w.settle(100)
            #expect(TimelinePlayhead.bodyRuns - before - neighbourRuns >= 1, "a redraw of this test's window didn't count")
            #endif
        }

        static func playhead(at frame: Int) -> TimelinePlayhead {
            TimelinePlayhead(
                mapping: FrameMapping(duration: 100, frameWidth: 4), playhead: frame, unit: .frames, fps: 24,
                scroll: .zero, keys: [], onScrub: { _ in })
        }

        /// Puts `view` in `w` and forces its layout and display, so its body runs now.
        static func show(_ view: TimelinePlayhead, in w: RenderBudgetWindow<TimelinePlayhead>) {
            w.rootView = view
            w.host.layoutSubtreeIfNeeded()
            w.window.displayIfNeeded()
        }
    }
}
#endif
