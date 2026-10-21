// RenderBudgetHaloHistoryTests.swift (autosave-history HA-4, quality row
// "render: arrow-key walk down 30 steps with the viewer live", packet
// docs/blueprints/halo/features/autosave-history.md): the real Halo window,
// through the harness (RenderBudgetHarness.swift), on `keyed` (live
// services) with Ball's x typed at 30 frames and all 30 undone, so "New
// Project" is current, the History panel shown and the viewer drawing. Thirty
// Down presses at 120 Hz walk the panel's selection to step 30 without a
// jump: at most 3 window bodies (target 0: the selection is the panel's own
// state, so only the panel and the two rows whose selection changed redraw).
// The p95 (packet: ≤ 8 ms) is printed, not gated: a step-time budget belongs
// in a Tests/perf-suites.txt test. Keys need a key window, so, as
// RenderBudgetHistoryPanelTests does, this asks the harness for a key-capable
// window, focuses the panel by a click on its current row (a jump to
// where it already is) and sends the presses through the window. Nested in
// BodyCountSuites: it reads global counters. macOS only.
#if canImport(AppKit)
import AppKit
import HaloModel
import SwiftUI
import Testing

@testable import HaloApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetHaloHistoryTests {
        static let steps = 30

        @Test(.timeLimit(.minutes(2))) func arrowWalkInThreeBodies() async throws {
            var project = try HaloHistoryAreaTests.edited(Self.steps)
            for _ in 0..<Self.steps { project.undo() }
            #expect(project.historyListing.index == 0 && project.historyListing.steps.count == Self.steps)
            let w = RenderBudgetWindow(
                HaloWindow(model: project).environment(\.haloHistoryShelf, HaloHistoryShelf(shown: true)),
                keyCapable: true)
            defer { w.close() }
            w.window.makeKey()
            _ = w.window.makeFirstResponder(w.host)
            try await w.settle(untilStable: HaloWindowPlaybackTests.windowBodies)
            let open = try #require(await w.element("suite.history.row.0"), "the panel shows no New Project row")
            w.click(at: CGPoint(x: open.midX, y: open.midY))
            if let panel = RenderBudgetHistoryPanelTests.node("suite.history", in: w.host) {
                panel.setAccessibilityFocused?(true)
            }
            try await w.settle(untilStable: HaloWindowPlaybackTests.windowBodies)
            let jumped = Self.jumps()
            let step = try await w.measure(
                "halo history arrow walk, \(Self.steps) steps", bodies: HaloWindowPlaybackTests.windowBodies
            ) {
                try await w.ticks(Self.steps) { _ in
                    RenderBudgetHistoryPanelTests.press(NSDownArrowFunctionKey, keyCode: 125, in: w.window)
                }
            }
            _ = await w.element("suite.history.row.\(Self.steps)")
            let last = RenderBudgetHistoryPanelTests.node("suite.history.row.\(Self.steps)", in: w.host)
            #expect(last?.isAccessibilitySelected?() == true, "the arrows didn't walk the selection to step \(Self.steps)")
            if let jumped, let now = Self.jumps() { #expect(now == jumped, "the arrows jumped \(now - jumped) times") }
            expectBodies(step, atMost: 3, target: 0)
        }

        /// The window's jumps so far; nil in release, which has no counter.
        static func jumps() -> Int? {
            #if DEBUG
            return HaloWindow.historyJumps
            #else
            return nil
            #endif
        }
    }
}
#endif
