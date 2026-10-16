// RenderBudgetLibraryTests.swift: Library's render budget
// (Tests/render-budgets.md) on the real window, through the harness
// (RenderBudgetHarness.swift). On the `samples` fixture (60 photos) it scrolls
// the grid 120 steps of 12 points, back to the top, then clicks 10 cells one
// after another. `bodies` gates the window-body counts; `timing`
// (Tests/perf-suites.txt, report-only) judges the step times. The loupe's step
// isn't driven: the loupe takes its arrow keys through SwiftUI focus, which
// needs a key window, and a test process can't have one. Nested in
// BodyCountSuites, as every suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import LibraryModel
import SwiftUI
import Testing

@testable import LibraryApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetLibraryTests {
        @Test(.timeLimit(.minutes(2))) func bodies() async throws {
            let (scroll, select) = try await Self.run()
            // Scrolling is presentation only. Target: 0.
            expectBodies(scroll, atMost: 0, target: 0)  // dev: 0
            // Each click is one selection change: one body each. Target: 10.
            expectBodies(select, atMost: 10, target: 10)  // dev: 10
        }

        @Test(.timeLimit(.minutes(2))) func timing() async throws {
            let (scroll, select) = try await Self.run()
            // Targets: a scroll step fits one 120 Hz frame; a selection two 60 Hz frames.
            expectP95(scroll, atMost: 10, target: 8.3)  // dev: 6.6 ms
            expectP95(select, atMost: 120, target: 33)  // dev: 80 ms
        }

        static func run() async throws -> (scroll: RenderStep, select: RenderStep) {
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
            let cells = w.identifiers().filter { $0.hasPrefix(LibraryGrid.cellIdentifierPrefix) }
            let first = try #require(cells.first, "no grid cells")
            let cell = try #require(await w.element(first))
            let grid = try #require(w.scrollView(at: CGPoint(x: cell.midX, y: cell.midY)), "no grid scroll view")
            var scrolled: (before: CGFloat, after: CGFloat) = (0, 0)
            let scroll = try await w.measure("library grid scroll, 120 steps", bodies: bodies) {
                scrolled = try await w.scroll(grid, by: 12)
            }
            #expect(scrolled.after > scrolled.before, "the grid never scrolled: \(scrolled)")
            _ = try await w.scroll(grid, by: -100_000, samples: 1)
            try await w.settle(200)
            var boxes: [CGRect] = []
            for id in cells.prefix(10) { if let box = await w.element(id) { boxes.append(box) } }
            let select = try await w.measure("library grid selection, 10 clicks", bodies: bodies) {
                try await w.ticks(boxes.count) { w.click(at: CGPoint(x: boxes[$0 - 1].midX, y: boxes[$0 - 1].midY)) }
            }
            #expect(boxes.count == 10 && (select.bodies ?? 1) >= 1, "the clicks selected nothing: \(select)")
            return (scroll, select)
        }
    }
}
#endif
