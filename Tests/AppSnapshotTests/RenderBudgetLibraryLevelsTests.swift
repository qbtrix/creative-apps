// RenderBudgetLibraryLevelsTests.swift: Library's Levels drag on the real
// window (#3633; Tests/render-budgets.md), through the harness
// (RenderBudgetHarness.swift). On the `samples` fixture it opens the first
// cell in the loupe with the cell's "Open" action, switches to Develop and
// drags the Midtones handle (LevelsHandles) 30 pt left over 120 samples at
// 120 Hz, the move that re-renders the loupe preview and its histogram every
// sample. `bodies` gates the window-body count; the step time is printed and
// judged nowhere (timing rows live in perf-suites). Nested in BodyCountSuites,
// as every suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import LibraryModel
import SwiftUI
import Testing

@testable import LibraryApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetLibraryLevelsTests {
        @Test(.timeLimit(.minutes(2))) func bodies() async throws {
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
            let first = try #require(w.identifiers().first { $0.hasPrefix(LibraryGrid.cellIdentifierPrefix) })
            #expect(w.perform("Open", on: first), "no Open action on \(first)")
            try await w.settle(500)
            let tab = try #require(await w.element("library.inspector.develop"), "no Develop tab")
            w.click(at: CGPoint(x: tab.midX, y: tab.midY))
            try await w.settle(untilStable: bodies, turns: 8)
            let handle = try #require(await w.element(DevelopInspector.levelsID(.gamma)), "no Midtones handle")
            let drag = try await w.measure("library levels midtones drag, 120 samples", bodies: bodies) {
                try await w.drag(from: CGPoint(x: handle.midX, y: handle.midY), by: CGVector(dx: -30, dy: 0))
            }
            #expect((drag.bodies ?? 1) >= 1, "the drag changed nothing: \(drag)")
            // Measured on dev with this PR; see Tests/render-budgets.md.
            expectBodies(drag, atMost: Self.budget, target: Self.budget)
        }

        static let budget = 121
    }
}
#endif
