// LayerTreeListTests.swift (EK-4): LayerTreeList over the kernel fixture
// `tree200`, every container open as the gallery's `editor-kernel` page shows
// it. Each row is keyed by its layer's own id (200 rows, no duplicates); a drop
// onto an open container lands as its last child, and a drop onto a leaf, a
// locked group, the row itself or its own descendant is refused; the page is
// in the gallery index. The list shows no scroller, whose page area the app
// audit reads as an unnamed button with no identifier (#2742). As a sidebar
// layers panel (#2811) it selects, renames (a refusal keeps the draft), names
// its toggles as SidebarRow does and runs its header action. macOS only.
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

    /// The list as a sidebar layers panel (#2811): a click selects, a rename
    /// goes out with the row's id and a refusal keeps the draft, the toggles
    /// carry SidebarRow's ids and labels inside `suite.sidebar`, and the
    /// header's New Layer button runs its action.
    @Test func sidebarPanel() throws {
        let rows = KernelFixtures.tree200.rows(expanded: [])
        let ball = try #require(rows.first)
        let calls = PanelCalls()
        let list = LayerTreeList(
            rows: rows, childCount: { _ in 0 }, selection: ball.id, naming: .sidebar,
            header: LayerTreeHeader(
                title: "Layers", action: ToolbarAction("New Layer", systemImage: "plus") { calls.added += 1 }),
            onSelect: { calls.picked.append($0) },
            onRename: { id, name in
                calls.renamed.append("\(id)=\(name)")
                return name == "Taken" ? "A layer named “Taken” already exists." : nil
            },
            onAction: { _ in })

        #expect(list.isSelected(ball.id) && !list.isSelected("nosuch"))
        list.select("header")
        #expect(calls.picked == ["header"])

        var field = SidebarRenameField()
        field.open(ball.name)
        field.type("Taken ")
        field.commit(original: ball.name, rename: list.rename(ball.id))
        #expect(field.isOpen && field.draft == "Taken " && field.message == "A layer named “Taken” already exists.")
        field.type("Sky")
        field.commit(original: ball.name, rename: list.rename(ball.id))
        #expect(!field.isOpen)
        #expect(calls.renamed == ["\(ball.id)=Taken", "\(ball.id)=Sky"])
        #expect(LayerTreeList(rows: rows, childCount: { _ in 0 }, onAction: { _ in }).rename(ball.id) == nil)

        let naming = list.naming
        #expect(naming.container == "suite.sidebar")
        #expect(naming.renameField("ball") == "suite.sidebar.ball.rename")
        var shown = ball
        shown.id = "ball"
        shown.name = "Ball"
        shown.isHidden = false
        shown.isLocked = false
        var hiddenLocked = shown
        hiddenLocked.isHidden = true
        hiddenLocked.isLocked = true
        #expect(naming.identifier(of: naming.visibility(shown), in: "ball") == "suite.sidebar.ball.visible")
        #expect(naming.identifier(of: naming.lock(shown), in: "ball") == "suite.sidebar.ball.locked")
        #expect([naming.visibility(shown).title, naming.lock(shown).title] == ["Hide Layer", "Lock Layer"])
        #expect([naming.visibility(hiddenLocked).title, naming.lock(hiddenLocked).title] == ["Show Layer", "Unlock Layer"])
        // The list's own naming, which older callers keep.
        #expect(LayerTreeNaming.layers.identifier(of: LayerTreeNaming.layers.visibility(shown), in: "ball")
            == "suite.layers.ball.eye")
        #expect(LayerTreeNaming.layers.lock(shown).title == "Lock Ball")
        #expect(LayerTreeNaming.layers.row("ball") == "suite.layers.row.ball")

        let header = try #require(list.header)
        #expect(header.section.addAction?.title == "New Layer")
        header.action?.perform()
        #expect(calls.added == 1)
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

/// What the panel's closures were called with.
@MainActor private final class PanelCalls {
    var picked: [String] = []
    var renamed: [String] = []
    var added = 0
}
