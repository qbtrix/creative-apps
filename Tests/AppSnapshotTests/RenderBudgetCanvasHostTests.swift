// RenderBudgetCanvasHostTests.swift: what the canvas host costs in a real
// 1280 x 820 window (canvas-host packet, Quality tests). A 120-sample drag
// across the `canvas-host` page runs at most 1 window body (the mouse-up
// commit), reaches the page's delegate as 120 samples and commits once; one
// switch on the `settings-rendering` page runs at most 2 (the menu's host and
// the status bar). CH-5 enables the drag on CH-3's host. The switch stays
// disabled: its items exist only while the pull-down's menu is open, so the
// harness finds no element to press (SJ28 drives it). Nested in
// BodyCountSuites: it reads a global body counter. macOS only.
import AppKit
import SwiftUI
import Testing

@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetCanvasHostTests {
        @Test(.timeLimit(.minutes(2))) func dragRunsNoBodies() async throws {
            let log = CanvasHostLog()
            let w = RenderBudgetWindow(CanvasHostBudgetHost { CanvasHostPage(log: log) })
            defer { w.close() }
            try await w.settle(600)
            // The host's frame when its accessibility element is found, else the window's: either way its middle
            // is on the centred artboard.
            let canvas = await w.element(RenderingControlID.canvas) ?? w.host.convert(w.host.bounds, to: nil)
            let start = CGPoint(x: canvas.midX - 300, y: canvas.midY)
            let bodies = { () -> Int? in
                #if DEBUG
                return CanvasHostBudgetHost<CanvasHostPage>.bodyRuns + CanvasHostPage.bodyRuns
                #else
                return nil
                #endif
            }
            let step = try await w.measure("canvas host drag, 120 samples", bodies: bodies) {
                try await w.drag(from: start, by: CGVector(dx: 600, dy: 0))
            }
            // The mouse-up commit logs one line: one body. Target: 1.
            expectBodies(step, atMost: 1, target: 1)
            #expect(log.drags == 120, "the delegate heard \(log.drags) of 120 drag samples")
            #expect(log.endDrags == 1, "the drag committed \(log.endDrags) times")
        }

        @Test(
            .disabled("the pull-down's items exist only while its menu is open; SJ28 drives the switch"),
            .timeLimit(.minutes(2))
        ) func switchRepaintsOnce() async throws {
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
