// RenderBudgetLibraryFoldersTests.swift: the FOLDERS section's render budget (folders FO-3b,
// Tests/render-budgets.md) on the real Library window at 10,000 photos (the `large` fixture), through the
// harness (RenderBudgetHarness.swift). Until FO-4 builds the tree from the photos, the section shows
// LibraryFoldersSection.sample (`stubTree`). Once the window body is still, it clicks the first folder's
// disclosure open and then closed. The group keeps its own open state, so the window body should not run
// (budget 2) and the content, the grid with it, never does (LibraryBrowser.bodyRuns stays put). Fails when
// expanding a folder re-renders the grid or more than two window bodies. Nested in BodyCountSuites, as every
// suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import LibraryModel
import SwiftUI
import Testing

@testable import LibraryApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetLibraryFoldersTests {
        @Test(.timeLimit(.minutes(2))) func expandFolderInTwoBodies() async throws {
            LibraryFoldersSection.stubTree = LibraryFoldersSection.sample
            defer { LibraryFoldersSection.stubTree = nil }
            let w = RenderBudgetWindow(LibraryWindow(arguments: ["Library", "-LibraryFixture", "large"]))
            defer { w.close() }
            try await w.settle(800)
            let bodies = { () -> Int? in
                #if DEBUG
                return LibraryWindow.bodyRuns
                #else
                return nil
                #endif
            }
            let content = { () -> Int in
                #if DEBUG
                return LibraryBrowser.bodyRuns
                #else
                return 0
                #endif
            }
            try await w.settle(untilStable: bodies, turns: 8)
            let outline = try #require(await w.first(NSOutlineView.self), "no sidebar outline")
            let row = try #require(
                (0..<outline.numberOfRows).first { outline.isExpandable(outline.item(atRow: $0)) },
                "no folder with a disclosure")
            let triangle = outline.frameOfOutlineCell(atRow: row)
            let point = outline.convert(CGPoint(x: triangle.midX, y: triangle.midY), to: nil)
            let rows = outline.numberOfRows
            let grid = content()
            var opened = 0
            let step = try await w.measure("library folder expand and collapse", bodies: bodies) {
                try await w.ticks(2) { tick in
                    w.click(at: point)
                    if tick == 1 { opened = outline.numberOfRows }
                }
            }
            #expect(opened > rows, "the click never opened the folder: \(rows) rows, then \(opened)")
            // Expansion is the group's own state. Target: 0.
            expectBodies(step, atMost: 2, target: 0)
            #expect(content() == grid, "expanding a folder re-rendered the content and its grid")
        }
    }
}
#endif
