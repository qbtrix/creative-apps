// RenderBudgetCanvasHostTests.swift: what the canvas host costs in a real
// 1280 x 820 window (canvas-host packet, Quality tests). A 120-sample drag
// across the `canvas-host` page runs at most 1 window body (the mouse-up
// commit); one switch on the `settings-rendering` page runs at most 2 (the
// menu's host and the status bar). CH-2 writes both disabled over the
// placeholder pages; CH-5 enables them once CH-3's host and CH-4's menu are
// on the pages. Nested in BodyCountSuites: it reads a global body counter.
// macOS only.
import AppKit
import SwiftUI
import Testing

@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetCanvasHostTests {
        @Test(.disabled("waits on CH-5"), .timeLimit(.minutes(2))) func dragRunsNoBodies() async throws {
            let w = RenderBudgetWindow(CanvasHostBudgetHost { CanvasHostPage() })
            defer { w.close() }
            try await w.settle(600)
            let box = w.host.convert(w.host.bounds, to: nil)
            let start = CGPoint(x: box.midX - 300, y: box.midY)
            let step = try await w.measure("canvas host drag, 120 samples", bodies: { CanvasHostBudgetHost<CanvasHostPage>.bodyRuns }) {
                try await w.drag(from: start, by: CGVector(dx: 600, dy: 0))
            }
            #expect((step.bodies ?? 0) <= 1, "the window ran \(step.bodies ?? 0) bodies for the drag: \(step)")
        }

        @Test(.disabled("waits on CH-5"), .timeLimit(.minutes(2))) func switchRepaintsOnce() async throws {
            let w = RenderBudgetWindow(CanvasHostBudgetHost { RenderingPanePage() })
            defer { w.close() }
            try await w.settle(600)
            let step = try await w.measure("rendering switch", bodies: { CanvasHostBudgetHost<RenderingPanePage>.bodyRuns }) {
                w.perform("press", on: RenderingControlID.item(.cpu))
            }
            #expect((step.bodies ?? 0) <= 2, "the window ran \(step.bodies ?? 0) bodies for one switch: \(step)")
        }
    }
}

/// A page under test, counting its own bodies: the window bodies the budget counts.
private struct CanvasHostBudgetHost<Page: View>: View {
    @MainActor static var bodyRuns: Int { CanvasHostBudgetCounter.runs[ObjectIdentifier(Page.self), default: 0] }
    let page: () -> Page

    var body: some View {
        let _ = CanvasHostBudgetCounter.runs[ObjectIdentifier(Page.self), default: 0] += 1
        page()
    }
}

/// Body runs per page type (a generic type can't hold its own static stored property).
@MainActor private enum CanvasHostBudgetCounter {
    static var runs: [ObjectIdentifier: Int] = [:]
}
