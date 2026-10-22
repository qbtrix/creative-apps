// RenderBudgetLibraryShareTests.swift: Share's render budget (share-sheet
// SH-4b, Tests/render-budgets.md) on the real window, through the harness
// (RenderBudgetHarness.swift). On the `samples` fixture it selects three
// cells, then presses the grid's Share button (`suite.share`): preparing is
// the button's own state, so the window body runs at most twice. On the SH-1
// stubs the button is off and the press is a no-op; SH-3 makes it prepare.
// Nested in BodyCountSuites, as every suite that reads a body counter is.
// macOS only.
#if canImport(AppKit)
import AppKit
import LibraryModel
import SwiftUI
import Testing

@testable import LibraryApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetLibraryShareTests {
        @Test(.timeLimit(.minutes(2))) func prepareThreeInTwoBodies() async throws {
            let w = RenderBudgetWindow(LibraryWindow(arguments: ["Library", "-LibraryFixture", "samples"]))
            defer { w.close() }
            try await w.settle(800)
            let bodies = { () -> Int? in
                #if DEBUG
                return LibraryWindow.bodyRuns
                #else
                return nil
                #endif
            }
            try await w.settle(untilStable: bodies, turns: 8)
            let cells = w.identifiers().filter { $0.hasPrefix(LibraryGrid.cellIdentifierPrefix) }
            var boxes: [CGRect] = []
            for id in cells.prefix(3) { if let box = await w.element(id) { boxes.append(box) } }
            #expect(boxes.count == 3, "no three grid cells")
            // A plain click per cell; the selection's own bodies are RenderBudgetLibraryTests' budget.
            for box in boxes { w.click(at: CGPoint(x: box.midX, y: box.midY)) }
            try await w.settle(untilStable: bodies, turns: 8)
            let share = try #require(await w.element("suite.share"), "the grid has no Share button")
            let press = try await w.measure("library share prepare, 1 press", bodies: bodies) {
                try await w.ticks(1) { _ in w.click(at: CGPoint(x: share.midX, y: share.midY)) }
            }
            // Target: 0 (the phase is the button's); a later prepare may refresh the window once.
            expectBodies(press, atMost: 2, target: 0)
        }
    }
}
#endif
