// RenderBudgetEditorKernelTests.swift: what the gallery's `editor-kernel` page
// costs in a real 1280 x 820 window (editor-kernel packet, EK-6, verification
// row EK-6). It scrolls LayerTreeList over `tree200` (200 rows, every
// container open) to its end, where Card 7's and Header's rows are, then
// drags Card 7 onto Header in 120 samples at 120 Hz: the page runs at most 3
// window bodies (the drop's log line and move; target 1, the packet's journey
// step 2). The drop target lights in the list's own state, never the page's,
// and only on enter and exit. The harness's presses are window-activation
// clicks, so whether the drag session lands is proved by the journey
// (`testEditorKernelGallery`), not here; this bounds what the drag costs.
// Nested in BodyCountSuites: it reads a global body counter. macOS only.
#if canImport(AppKit)
import AppKit
import SwiftUI
import Testing

@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetEditorKernelTests {
        @Test(.timeLimit(.minutes(2))) func testTreeDragBodies() async throws {
            let w = RenderBudgetWindow(GalleryEditorKernelPage())
            defer { w.close() }
            try await w.settle(600)
            let bodies = { () -> Int? in
                #if DEBUG
                return GalleryEditorKernelPage.bodyRuns
                #else
                return nil
                #endif
            }
            // Rows run front to back, so Header (row 197 of 200) and Card 7 (row 184) sit at the list's end.
            let list = try #require(await w.element("suite.layers"), "no LayerTreeList (suite.layers) on the page")
            let scroller = try #require(w.scrollView(at: CGPoint(x: list.midX, y: list.midY)), "the list has no scroll view")
            _ = try await w.scroll(scroller, by: 60)
            try await w.settle(untilStable: bodies)
            let card = try #require(await w.element("suite.layers.row.card-7"), "no row for Card 7 at the list's end")
            let header = try #require(await w.element("suite.layers.row.header"), "no row for Header at the list's end")
            let start = CGPoint(x: card.minX + card.width * 0.4, y: card.midY)
            let end = CGPoint(x: header.minX + header.width * 0.4, y: header.midY)
            let step = try await w.measure("editor-kernel tree drag, 120 samples", bodies: bodies) {
                try await w.drag(from: start, by: CGVector(dx: end.x - start.x, dy: end.y - start.y))
            }
            // The drop writes one log line and moves one row: one body. Target: 1.
            expectBodies(step, atMost: 3, target: 1)
        }
    }
}
#endif
