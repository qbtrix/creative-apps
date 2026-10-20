// RenderBudgetCommandCatalogTests.swift: what the gallery's `command-catalog`
// page costs in a real 1280 x 820 window (command-catalog packet, CC-10,
// verification row CC-10). From the empty document it clicks Add Rectangle,
// then every other row in menu order (Move and Remove now enabled on the new
// rect), then the Edit row's Undo: each click runs at most 2 window bodies
// (the run's document change and its log line land in one; target 1). A
// disabled row's click runs none. Whether a click runs its spec is proved by
// the journey (`testCommandCatalogGallery`); this bounds what each costs.
// Nested in BodyCountSuites: it reads a global body counter. macOS only.
#if canImport(AppKit)
import AppKit
import SwiftUI
import Testing

@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetCommandCatalogTests {
        /// The rows clicked, in order: Add first so the rest have a rect to act on, Undo last.
        static let clicks = ["rect.add", "rect.move", "rect.select", "rect.list", "doc.export-json", "rect.remove", "edit.undo"]

        @Test(.timeLimit(.minutes(2))) func rowClick() async throws {
            #expect(Set(Self.clicks.dropLast()) == Set(GalleryCommandCatalog.rows.map(\.id)))
            let w = RenderBudgetWindow(GalleryCommandCatalogPage())
            defer { w.close() }
            try await w.settle(600)
            let bodies = { () -> Int? in
                #if DEBUG
                return GalleryCommandCatalogPage.bodyRuns
                #else
                return nil
                #endif
            }
            try await w.settle(untilStable: bodies)
            for id in Self.clicks {
                let row = try #require(await w.element("suite.gallery.command-catalog.\(id)"), "no row for \(id)")
                let step = try await w.measure("command-catalog \(id) click", bodies: bodies) {
                    try await w.ticks(1) { _ in w.click(at: CGPoint(x: row.midX, y: row.midY)) }
                }
                // One run changes the document and appends a log line: one body. Target: 1.
                expectBodies(step, atMost: 2, target: 1)
                try await w.settle(untilStable: bodies)
            }
        }
    }
}
#endif
