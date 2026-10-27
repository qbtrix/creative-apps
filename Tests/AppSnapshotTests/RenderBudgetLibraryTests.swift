// RenderBudgetLibraryTests.swift: Library's render budget
// (Tests/render-budgets.md) on the real window, through the harness
// (RenderBudgetHarness.swift). On the `samples` fixture (60 photos) it scrolls
// the grid 120 steps of 12 points once the window body is still
// (`settle(untilStable:)`), back to the top, then clicks 10 cells one
// after another. `bodies` gates the window-body counts; `timing`
// (Tests/perf-suites.txt, report-only) judges the step times. The loupe's step
// isn't driven: the loupe takes its arrow keys through SwiftUI focus, which
// needs a key window, and a test process can't have one. `rotateInLoupe`
// (orientation-crop OC-10) opens the `shoot` fixture's first 24 MP photo and
// turns it once through the loupe photo's Rotate Right action. Nested in
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

        /// orientation-crop OC-10: Photo > Rotate Right on the loupe's 24 MP photo is one edit, so at most
        /// two window bodies (the edit, then its render landing); its p95 is reported, not gated.
        /// The loupe photo's "Rotate Right" accessibility action runs Photo > Rotate Right.
        @Test(.timeLimit(.minutes(2))) func rotateInLoupe() async throws {
            let w = RenderBudgetWindow(LibraryWindow(arguments: ["Library", "-LibraryFixture", "shoot"]))
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
            let first = try #require(cells.first, "no grid cells")
            #expect(w.perform("Open", on: first), "the grid cell has no Open action")
            #expect(await w.element("library.loupe.photo") != nil, "Open showed no loupe photo")
            try await w.settle(untilStable: bodies, turns: 8)
            var turned = false
            let rotate = try await w.measure("library loupe rotate right, 24 MP", bodies: bodies) {
                try await w.ticks(1) { _ in turned = w.perform("Rotate Right", on: "library.loupe.photo") }
                try await w.settle(untilStable: bodies, turns: 8)
            }
            #expect(turned, "the loupe photo has no Rotate Right action")
            #expect((rotate.bodies ?? 1) >= 1, "Rotate Right changed nothing: \(rotate)")
            // The edit, then its render landing. Target: 2. The p95 (target 30 ms) is printed, not gated.
            expectBodies(rotate, atMost: 2, target: 2)
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
            // The launch restore can land after the first thumbnails, which keep the
            // pool busy; a late launch change isn't the scroll's cost (#2878 counted 1).
            try await w.settle(untilStable: bodies, turns: 8)
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
