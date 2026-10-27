// RenderBudgetLibraryFoldersTests.swift: the FOLDERS section's render budget (folders FO-3b,
// Tests/render-budgets.md) on the real Library window at 10,000 photos, through the harness
// (RenderBudgetHarness.swift). The `large-folders` fixture gives every photo a path, so the section is the tree
// the catalog builds from them: one root, a folder per month, each with selects inside. Once the window body is still, it presses the first folder's
// disclosure button (a row below level 0: section headers expand too) open and then closed, as a finished
// click does: flip its state, send its action. A scripted mouse-down would wait forever in AppKit's tracking
// loop for a mouse-up the harness can't deliver, and performClick runs AppKit's event loop, which leaves a
// stop for the test's main run loop that ends the process with exit 0 in a later test. The group keeps its
// own open state, so the window body should not run (budget 2) and the content, the grid with it, never does
// (LibraryBrowser.bodyRuns stays put). Fails when expanding a folder re-renders the grid or more than two
// window bodies. Nested in BodyCountSuites, as every suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import LibraryModel
import SwiftUI
import Testing

@testable import LibraryApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetLibraryFoldersTests {
        @Test(.timeLimit(.minutes(2))) func expandFolderInTwoBodies() async throws {
            let w = RenderBudgetWindow(LibraryWindow(arguments: ["Library", "-LibraryFixture", "large-folders"]))
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
            // Section headers sit at level 0 and are expandable too, with no disclosure cell; a folder is a row.
            let row = try #require(
                (0..<outline.numberOfRows).first {
                    outline.level(forRow: $0) > 0 && outline.isExpandable(outline.item(atRow: $0))
                },
                "no folder with a disclosure")
            let triangle = outline.frameOfOutlineCell(atRow: row)
            try #require(!triangle.isEmpty, "folder row \(row) has no disclosure cell")
            let point = outline.convert(CGPoint(x: triangle.midX, y: triangle.midY), to: nil)
            // The control a hand hits there; pressed without an event (see the header).
            let disclosure = try #require(
                w.window.contentView?.hitTest(point) as? NSButton, "no disclosure button on folder row \(row)")
            let rows = outline.numberOfRows
            let grid = content()
            var opened = 0
            let step = try await w.measure("library folder expand and collapse", bodies: bodies) {
                try await w.ticks(2) { tick in
                    // The rows the first press opened, a run-loop turn later, when SwiftUI has applied it.
                    if tick == 2 { opened = outline.numberOfRows }
                    // What a finished click does: flip the button's state, then send its action.
                    disclosure.state = disclosure.state == .on ? .off : .on
                    disclosure.sendAction(disclosure.action, to: disclosure.target)
                }
            }
            #expect(opened > rows, "the press never opened the folder: \(rows) rows, then \(opened)")
            // Expansion is the group's own state. Target: 0.
            expectBodies(step, atMost: 2, target: 0)
            #expect(content() == grid, "expanding a folder re-rendered the content and its grid")
        }
    }
}
#endif
