// LayerTreeListTests.swift (EK-4): LayerTreeList over the kernel fixture
// `tree200`, every container open as the gallery's `editor-kernel` page shows
// it. Each row is keyed by its layer's own id (200 rows, no duplicates); a drop
// onto an open container lands as its last child, and a drop onto a leaf, a
// locked group, the row itself or its own descendant is refused; the page is
// in the gallery index. The list shows no scroller, whose page area the app
// audit reads as an unnamed button with no identifier (#2742). macOS only.
@testable import SuiteUI
import SuiteKernel
import SwiftUI
import Testing

@MainActor @Suite struct LayerTreeListTests {
    @Test func rowsAndDropTargets() {
        let tree = KernelFixtures.tree200
        let rows = tree.rows(expanded: GalleryEditorKernel.allOpen(tree))
        let ids = LayerTreeList.rowIDs(rows)
        #expect(rows.count == 200)
        #expect(ids == rows.map(\.id))
        #expect(Set(ids).count == ids.count)
        #expect(ids.contains("card-7") && ids.contains("header") && ids.contains("item-4-3-9"))

        #expect(LayerTreeList.drop("card-7", onto: "header", in: rows, childCount: 0)
            == LayerDrop(id: "card-7", parent: "header", index: 3))
        #expect(LayerTreeList.drop("header-1", onto: "header", in: rows, childCount: 0)
            == LayerDrop(id: "header-1", parent: "header", index: 2))
        // Refused: a leaf, a locked group, the row itself, its own descendant.
        #expect(LayerTreeList.drop("card-7", onto: "card-8", in: rows, childCount: 0) == nil)
        #expect(LayerTreeList.drop("card-7", onto: "background", in: rows, childCount: 0) == nil)
        #expect(LayerTreeList.drop("card-7", onto: "footer", in: rows, childCount: 0) == nil)
        #expect(LayerTreeList.drop("cards", onto: "cards", in: rows, childCount: 0) == nil)
        #expect(LayerTreeList.drop("gallery", onto: "row-2-col-3", in: rows, childCount: 0) == nil)
        #expect(LayerTreeList.drop("nosuch", onto: "header", in: rows, childCount: 0) == nil)

        // A closed container takes the count its host names.
        let closed = tree.rows(expanded: [])
        #expect(LayerTreeList.drop("background", onto: "hero", in: closed, childCount: 5)
            == LayerDrop(id: "background", parent: "hero", index: 5))

        #expect(GalleryEditorKernel.line(.move(LayerDrop(id: "card-7", parent: "header", index: 3)), open: false)
            == "move(into: \"header\", at: 3)")
        #expect(SuiteGallery.pageNames.contains(GalleryEditorKernel.name))
        #expect(SuiteGallery.resolve("editor-kernel") == .page("editor-kernel"))
    }

    /// A legacy scroller's page area is a `button ''` to the app audit, so the
    /// list hides its scroll indicators (#2742; Design's list did the same, #2561).
    @Test func listShowsNoScroller() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(contentsOf: root.appending(path: "Sources/SuiteUI/LayerTreeList.swift"), encoding: .utf8)
        #expect(source.contains(".scrollIndicators(.never)"))
    }
}
