// PhotoHistogramCountTests.swift: the Curves histogram stops counting once
// its input moves on. AdjustmentsPanel counts off the main actor each time
// curvesHistogramKey rests for 150 ms; a count the next key change supersedes
// must stop, not run to its end. On a 100-layer image each count is seconds of
// CPU, and a run of toggles, nudges or slider steps left one count per step
// running long after the hand stopped (idle CPU findings #3662 to #3664).
// The panel is hosted on the render budget harness with a count that waits
// 2 s and notes whether it finished uncancelled; four exposure steps 250 ms
// apart (each rests past the 150 ms wait, so each starts a count) must finish
// one count, the last. macOS only.
#if canImport(AppKit)
import PhotoModel
import Synchronization
import SwiftUI
import Testing

@testable import PhotoApp

@MainActor @Suite struct PhotoHistogramCountTests {
    @Test(.timeLimit(.minutes(1))) func aSupersededCountStops() async throws {
        let finished = Mutex(0)
        let count: @Sendable (PhotoWorkspace) async -> [Double] = { _ in
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled { finished.withLock { $0 += 1 } }
            return []
        }
        var model = try PhotoWorkspace.fixture(.sample)
        let w = RenderBudgetWindow(AdjustmentsPanel(model: model, perform: { _ in }, count: count))
        defer { w.close() }
        // The first key's count, on appear, lands before the steps start.
        try await Task.sleep(for: .milliseconds(2600))
        let before = finished.withLock { $0 }
        for step in 1...4 {
            model.adjust(.exposure(Float(step) / 10))
            w.host.rootView = AdjustmentsPanel(model: model, perform: { _ in }, count: count)
            try await Task.sleep(for: .milliseconds(250))
        }
        try await Task.sleep(for: .milliseconds(2600))
        let after = finished.withLock { $0 }
        #expect(before == 1, "the first count never finished")
        #expect(after - before == 1, "\(after - before) of 4 counts ran to their end; only the last should")
    }
}
#endif
