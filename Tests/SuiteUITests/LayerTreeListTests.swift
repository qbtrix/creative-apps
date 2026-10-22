// LayerTreeListTests.swift (EK-4): LayerTreeList over the kernel fixture
// `tree200`, every container open as the gallery's `editor-kernel` page shows
// it. Each row is keyed by its layer's own id (200 rows, no duplicates); a drop
// onto an open container lands as its last child, and a drop onto a leaf, a
// locked group, the row itself or its own descendant is refused; the page is
// in the gallery index. The list shows no scroller, whose page area the app
// audit reads as an unnamed button with no identifier (#2742). As a sidebar
// layers panel (#2811) it selects, renames (a refusal keeps the draft), names
// its toggles as SidebarRow does and runs its header action. For the app
// panel swaps (#3194) it takes app ids, and a drop beside a flat row reorders
// it among its siblings (before, after, first, last; refused on a locked
// target or an unknown id), the root as parent at depth 0. Multi-select
// (multi-layer-select PM-1): Shift extends, Command toggles, a plain click
// replaces, and every id in `selected` draws selected. macOS only.
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

    /// The flat reorder rule (#3194): a drop beside a row moves the dragged
    /// row next to it in the row's own parent, as the kernel's move applies it.
    @Test func flatReorder() throws {
        let open: Set<String> = ["desktop"]
        func moved(_ id: String, beside target: String, below: Bool) throws -> [String] {
            var tree = KernelFixtures.cards
            let move = try #require(LayerTreeList.reorder(id, beside: target, below: below, in: tree.rows(expanded: open)))
            try tree.move(move.id, into: move.parentID, at: move.index)
            return tree.rows(expanded: open).map(\.id)
        }
        #expect(KernelFixtures.cards.rows(expanded: open).map(\.id)
            == ["desktop", "hidden", "locked", "pair", "title", "c", "b", "a"])
        #expect(LayerTreeList.reorder("a", beside: "c", below: false, in: KernelFixtures.cards.rows(expanded: open))
            == LayerDrop(id: "a", parent: "desktop", index: 2))
        #expect(try moved("a", beside: "c", below: false) == ["desktop", "hidden", "locked", "pair", "title", "a", "c", "b"])
        #expect(try moved("title", beside: "b", below: true) == ["desktop", "hidden", "locked", "pair", "c", "b", "title", "a"])
        #expect(try moved("b", beside: "hidden", below: false) == ["desktop", "b", "hidden", "locked", "pair", "title", "c", "a"])
        #expect(try moved("hidden", beside: "a", below: true) == ["desktop", "locked", "pair", "title", "c", "b", "a", "hidden"])

        // Refused: a locked target, an unknown id, the row itself, its own descendant.
        let rows = KernelFixtures.cards.rows(expanded: ["desktop", "pair"])
        #expect(LayerTreeList.reorder("a", beside: "locked", below: false, in: rows) == nil)
        #expect(LayerTreeList.reorder("nosuch", beside: "a", below: false, in: rows) == nil)
        #expect(LayerTreeList.reorder("a", beside: "nosuch", below: true, in: rows) == nil)
        #expect(LayerTreeList.reorder("a", beside: "a", below: true, in: rows) == nil)
        #expect(LayerTreeList.reorder("pair", beside: "e1", below: true, in: rows) == nil)
        let all = KernelFixtures.tree200.rows(expanded: ["footer"])
        #expect(LayerTreeList.reorder("background", beside: "footer-1", below: false, in: all) == nil)

        // At depth 0 the parent is the root.
        let roots = KernelFixtures.tree200.rows(expanded: [])
        let top = try #require(LayerTreeList.reorder("background", beside: "header", below: false, in: roots))
        #expect(top == LayerDrop(id: "background", parent: LayerDrop.root, index: 1) && top.parentID == nil)
        var tree = KernelFixtures.tree200
        try tree.move(top.id, into: top.parentID, at: top.index)
        #expect(tree.rows(expanded: []).suffix(2).map(\.id) == ["background", "header"])
    }

    /// App naming (#3194): the container, row and control ids Photo and Halo
    /// journeys use; every new option defaults off.
    @Test func appNaming() {
        let photo = LayerTreeNaming.app(LayerTreeIDs(container: "photo.layers", row: "photo.layer.row.", control: "photo.layer."))
        var row = KernelFixtures.tree200.rows(expanded: [])[0]
        row.id = "7"
        row.name = "Sky"
        row.isHidden = false
        #expect(photo.container == "photo.layers")
        #expect(photo.identifier(of: photo.visibility(row), in: "7") == "photo.layer.7.eye")
        #expect(photo.control("7", "kind") == "photo.layer.7.kind")
        #expect(photo.visibility(row).title == "Hide Sky")
        let halo = LayerTreeNaming.app(LayerTreeIDs(container: "halo.layers", row: "halo.layer.row.", control: "halo.layer."))
        #expect(halo.row("l1") == "halo.layer.row.l1")
        // The built-in namings keep their ids.
        #expect(LayerTreeNaming.layers.disclosure("hero") == "suite.layers.hero.disclose")
        #expect(LayerTreeNaming.sidebar.renameMessage("hero") == "suite.sidebar.hero.renameMessage")

        let options = LayerTreeOptions()
        #expect(options.showsEye && options.showsLock && !options.reorders && !options.embedded)
        let flat = LayerTreeOptions(showsEye: false, showsLock: false, reorders: true, embedded: true)
        #expect(!flat.showsEye && !flat.showsLock && flat.reorders && flat.embedded)
        let kind = LayerRowDecoration(symbol: "photo", symbolID: "photo.layer.7.kind", caption: "Pixel · 100%")
        #expect(kind.caption == "Pixel · 100%" && kind.thumbnail == nil && kind.help == nil)
    }

    /// The click's mode (PM-1): Shift extends, Command toggles, a plain click
    /// replaces; Shift wins when both are held.
    @Test func pickModes() {
        #expect(LayerTreeList.pick(shift: true, command: false) == .extend)
        #expect(LayerTreeList.pick(shift: false, command: true) == .toggle)
        #expect(LayerTreeList.pick(shift: false, command: false) == .replace)
        #expect(LayerTreeList.pick(shift: true, command: true) == .extend)
    }

    /// With two ids picked both rows read selected and a click goes out
    /// through `onPick`; the single `selection:` init still draws one row.
    @Test func severalSelected() {
        let rows = KernelFixtures.tree200.rows(expanded: [])
        let calls = PanelCalls()
        let list = LayerTreeList(
            rows: rows, childCount: { _ in 0 }, selected: ["header", "footer"],
            onPick: { id, _ in calls.picked.append(id) }, onAction: { _ in })
        #expect(list.isSelected("header") && list.isSelected("footer"))
        #expect(!list.isSelected("background") && !list.isSelected("nosuch"))
        list.select("background")
        #expect(calls.picked == ["background"])

        let single = LayerTreeList(rows: rows, childCount: { _ in 0 }, selection: "header", onAction: { _ in })
        #expect(single.isSelected("header") && !single.isSelected("footer"))
        let none = LayerTreeList(rows: rows, childCount: { _ in 0 }, selected: [], onPick: { _, _ in }, onAction: { _ in })
        #expect(!none.isSelected("header"))
    }

    /// Picked rows side by side join into one band: a row squares the edge it
    /// shares with a picked neighbour, and a lone picked row keeps every corner.
    @Test func adjacentPicksJoin() {
        let joins = LayerTreeList.selectionJoins(["a", "b", "c", "d", "e"], selected: ["a", "b", "c", "e"].contains)
        #expect(joins["a"] == LayerRowJoin(above: false, below: true))
        #expect(joins["b"] == LayerRowJoin(above: true, below: true))
        #expect(joins["c"] == LayerRowJoin(above: true, below: false))
        #expect(joins["d"] == nil && joins["e"] == nil)
        #expect(LayerTreeList.selectionJoins(["a", "b"], selected: { $0 == "b" }).isEmpty)
    }

    /// A flat leaf row of `tree200`, named Sky.
    private func flatRow() -> LayerRow {
        var row = KernelFixtures.tree200.rows(expanded: [])[0]
        row.id = "7"
        row.name = "Sky"
        row.depth = 0
        row.holdsChildren = false
        return row
    }

    /// `row` drawn alone with `options` and `decoration`, at its own size.
    private func size(_ row: LayerRow, options: LayerTreeOptions = .init(),
                      decoration: LayerRowDecoration? = nil) -> CGSize {
        NSHostingView(rootView: LayerTreeRow(
            row: row, lit: false, selected: false, naming: .layers, options: options, decoration: decoration,
            field: nil, onAction: { _ in }, onSelect: nil, onRename: nil)).fittingSize
    }

    /// Every row is one pointer-sized height: a caption under the name doesn't
    /// make its row jump taller than its neighbours (Photo's blend line).
    @Test func rowsShareOneHeight() {
        let plain = size(flatRow()).height
        let captioned = size(flatRow(), decoration: LayerRowDecoration(symbol: "photo", caption: "Multiply 60%")).height
        #expect(plain >= SuiteSize.studioRow, "plain row is \(plain) pt")
        #expect(abs(captioned - plain) <= 4, "caption row \(captioned) pt against plain \(plain) pt")
    }

    /// A list that never nests (Photo) leaves out the empty disclosure column.
    @Test func flatListHasNoDisclosureColumn() {
        #expect(LayerTreeOptions().nests)
        let nested = size(flatRow()).width
        let flat = size(flatRow(), options: LayerTreeOptions(nests: false)).width
        #expect(nested - flat >= SuiteSize.iconButtonHit, "flat \(flat) pt against nested \(nested) pt")
    }

    /// A row under the pointer shows it with fill and outline (fill alone is
    /// too faint in Dark); selection and a drop target win over hover.
    @Test func hoverLook() {
        #expect(LayerRowLook.resolve(selected: false, lit: false, hovering: false) == .rest)
        #expect(LayerRowLook.resolve(selected: false, lit: false, hovering: true) == .hover)
        #expect(LayerRowLook.resolve(selected: true, lit: false, hovering: true) == .selected)
        #expect(LayerRowLook.resolve(selected: true, lit: true, hovering: true) == .dropTarget)
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
