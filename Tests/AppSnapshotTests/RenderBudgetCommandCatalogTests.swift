// RenderBudgetCommandCatalogTests.swift (command-catalog CC-10): the gallery's
// `command-catalog` page in a 1280 x 820 window. From the empty document it
// clicks Add Rectangle, every other row, then Undo: each click runs at most 2
// window bodies (target 1). The journey proves the clicks run their specs.
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
                expectBodies(step, atMost: 2, target: 1)
                try await w.settle(untilStable: bodies)
            }
        }
    }
}
#endif
