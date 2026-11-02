// RenderBudgetLibraryFilesTests.swift (catalog-files LC-4): scrolling 10,000 photos, 500 missing, runs at
// most 3 window bodies (target 0), through RenderBudgetHarness.swift. macOS only.
#if canImport(AppKit)
import AppKit
import LibraryModel
import SwiftUI
import Testing

@testable import LibraryApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetLibraryFilesTests {
        @Test(.timeLimit(.minutes(2))) func missingBadgeScroll() async throws {
            let w = RenderBudgetWindow(LibraryWindow(arguments: ["Library", "-LibraryFixture", "large-missing"]))
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
            let ids = w.identifiers()
            #expect(ids.contains("library.grid.missing"), "no missing badge over the grid")
            let first = try #require(ids.first { $0.hasPrefix(LibraryGrid.cellIdentifierPrefix) }, "no grid cells")
            let cell = try #require(await w.element(first))
            let grid = try #require(w.scrollView(at: CGPoint(x: cell.midX, y: cell.midY)), "no grid scroll view")
            var scrolled: (before: CGFloat, after: CGFloat) = (0, 0)
            let scroll = try await w.measure("library grid scroll past 500 missing, 120 steps", bodies: bodies) {
                scrolled = try await w.scroll(grid, by: 12)
            }
            #expect(scrolled.after > scrolled.before, "the grid never scrolled: \(scrolled)")
            expectBodies(scroll, atMost: 3, target: 0)
        }
    }
}
#endif
