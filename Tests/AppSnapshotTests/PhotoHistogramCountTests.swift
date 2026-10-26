// PhotoHistogramCountTests.swift: the Curves histogram stops counting once
// its input moves on. AdjustmentsPanel counts off the main actor each time
// curvesHistogramKey rests for 150 ms; a count the next key change supersedes
// must stop, not run to its end. On a 100-layer image each count is seconds of
// CPU, and a run of toggles, nudges or slider steps left one count per step
// running long after the hand stopped (idle CPU findings #3662 to #3664).
// The panel is hosted on the render budget harness with a count that holds
// until the test lets it go and notes whether it ended uncancelled. The first
// key's count and four exposure steps each start one (the test waits for each
// to start, so no timing decides it); once they are let go, only the last
// may finish. macOS only.
#if canImport(AppKit)
import PhotoModel
import SuiteModel
import Synchronization
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor @Suite struct PhotoHistogramCountTests {
    @Test(.timeLimit(.minutes(1))) func aSupersededCountStops() async throws {
        let counts = Counts()
        var model = try PhotoWorkspace.fixture(.sample)
        let w = RenderBudgetWindow(AdjustmentsPanel(model: model, perform: { _ in }, count: counts.count))
        defer { w.close() }
        try await counts.waitForStarts(1)
        for step in 1...4 {
            model.adjust(.exposure(Float(step) / 10))
            w.host.rootView = AdjustmentsPanel(model: model, perform: { _ in }, count: counts.count)
            try await counts.waitForStarts(step + 1)
        }
        counts.release()
        try await Task.sleep(for: .milliseconds(500))
        let finished = counts.finished
        #expect(finished == 1, "\(finished) of 5 counts ran to their end; only the last should")
    }

    /// Counts that hold until `release`, noting how many started and how many ended uncancelled.
    final class Counts: Sendable {
        private let state = Mutex((started: 0, finished: 0, released: false))
        var finished: Int { state.withLock { $0.finished } }

        var count: @Sendable (PhotoWorkspace) async -> ToneHistogram {
            { [self] _ in
                state.withLock { $0.started += 1 }
                while !state.withLock({ $0.released }) {
                    do { try await Task.sleep(for: .milliseconds(20)) } catch { return .empty }
                }
                if !Task.isCancelled { state.withLock { $0.finished += 1 } }
                return .empty
            }
        }

        func release() { state.withLock { $0.released = true } }

        /// Waits (up to 20 s) until `n` counts have started.
        func waitForStarts(_ n: Int) async throws {
            for _ in 0..<1000 where state.withLock({ $0.started }) < n { try await Task.sleep(for: .milliseconds(20)) }
            try #require(state.withLock { $0.started } >= n, "count \(n) never started")
        }
    }
}
#endif
