// RenderBudgetLibraryBackupTests.swift: the Restore Catalog Backup sheet's
// render budget (catalog-backup BK-4b, Tests/render-budgets.md). On the
// `samples` fixture, once the window body is still, it opens the sheet with 17
// backups through the area's DEBUG hook (the menu item stays disabled until
// BK-3 lands real backups) and counts window bodies. The sheet's state lives
// in the backup area's own modifier, not in LibraryWindow, so opening it
// re-renders at most 2 window bodies (target 0) and never the grid: the grid
// is built in the window body, so with no window body it can't run, and its
// cells are the same before and after. The backup list is a List, whose rows
// report no accessibility children to a test process, so the row is found by
// RenderBudgetHistoryPanelTests.node (children, then subviews). Nested in
// BodyCountSuites, as every suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import LibraryModel
import SwiftUI
import Testing

@testable import LibraryApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetLibraryBackupTests {
        @Test(.timeLimit(.minutes(2))) func openSheetInTwoBodies() async throws {
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
            let cells = { w.identifiers().filter { $0.hasPrefix(LibraryGrid.cellIdentifierPrefix) } }
            let before = cells()
            #expect(!before.isEmpty, "no grid cells before the sheet opened")
            let rows = Self.rows(17)
            var hooked = false
            let open = try await w.measure("library backup sheet opens, 17 backups", bodies: bodies) {
                try await w.ticks(1) { _ in
                    #if DEBUG
                    hooked = LibraryBackupArea.present != nil
                    LibraryBackupArea.present?(rows)
                    #endif
                }
            }
            #expect(hooked, "the backup area never set its present hook")
            let sheet = try #require(await Self.sheet(of: w.window), "no sheet opened: \(open)")
            #expect(RenderBudgetHistoryPanelTests.node("library.backup.row", in: sheet) != nil, "the sheet shows no backup row")
            #expect(RenderBudgetHistoryPanelTests.node("library.backup.restore", in: sheet) != nil, "the sheet has no Restore button")
            // Opening a sheet changes no window state. Target: 0.
            expectBodies(open, atMost: 2, target: 0)  // dev: 0
            #expect(cells() == before, "the grid's cells changed while the sheet opened")
        }

        /// `count` backups an hour apart, newest first, each with its own photo count.
        static func rows(_ count: Int) -> [LibraryBackupRow] {
            (0..<count).map { i in
                LibraryBackupRow(name: "catalog backup \(i).json", date: 1_792_000_000 - Double(i) * 3600, photos: 60 - i)
            }
        }

        /// The sheet attached to `window`, waiting up to two seconds for SwiftUI to present it.
        static func sheet(of window: NSWindow) async -> NSWindow? {
            for _ in 0..<100 {
                if let sheet = window.attachedSheet { return sheet }
                try? await Task.sleep(for: .milliseconds(20))
            }
            return nil
        }
    }
}
#endif
