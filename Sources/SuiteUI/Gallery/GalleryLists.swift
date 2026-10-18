// GalleryLists.swift: the gallery's lists-and-layers pages (packet
// docs/blueprints/suiteui/features/lists-and-layers.md, LL-13). Each page owns
// its state in @State and writes one line per action to the
// `suite.gallery.log` element the journeys read.
//
// `window` draws a real SuiteWindow through its internal init, which skips
// the -SuiteGallery check, so the page never opens the gallery inside itself.
// Its Layers section holds Hero, Ball, Shadow and Group (one child), each
// with an eye and a lock (`toggle eye ball`, `toggle lock shadow locked`; a
// hidden or locked row dims), a rename the page refuses for "Taken" (LL-7:
// `rename ball Hero`), drag to reorder (`move shadow 0`), a context menu with
// Duplicate (`menu duplicate ball`) and a disabled Delete that says why
// (LL-8a), and Group's expansion owned by the page (LL-9: `open group`). The
// empty Pages section shows its header only.
//
// `layers` and `layers-300` show LayerTreeList (the kernel fold withdrew
// LayerList) over a small tree and a 300-node one, every container open,
// logged in GalleryEditorKernel's words. `grid` (24 cells) and `grid-2000`
// show ThumbnailGrid; a selection logs its sorted ids (`3,4,5,6`), a
// double-click `open 3`. Cells register as `suite.grid.<id>`.
//
// -SuiteGalleryFakes swaps the contracts the pages call: the window reorders
// through FakeListEditing and the grids select through FakeGridSelecting
// (single selection). The layer pages call no list contract, so they look
// the same with it.
import SuiteKernel
import SwiftUI

enum GalleryLists {
    static let feature = "lists-and-layers"

    @MainActor static let pages: GalleryPages = [
        "window": { AnyView(GalleryWindowPage()) },
        "layers": { AnyView(GalleryLayersPage(tree: small)) },
        "layers-300": { AnyView(GalleryLayersPage(tree: large)) },
        "grid": { AnyView(GalleryGridPage(count: 24)) },
        "grid-2000": { AnyView(GalleryGridPage(count: 2000)) },
    ]

    /// The refusal the window page shows under a rename to "Taken".
    static let taken = "Another layer is already named Taken."
    /// Why the row menu's Delete is disabled.
    static let deleteHelp = "The gallery keeps every layer, so Delete is unavailable here."

    /// The layer pages' payload: only whether a layer holds children.
    struct Layer: LayerPayload {
        var holdsChildren: Bool
    }

    static func leaf(_ id: String, _ name: String, locked: Bool = false) -> LayerNode<Layer> {
        LayerNode(id: id, name: name, isLocked: locked, payload: Layer(holdsChildren: false))
    }

    static func group(_ id: String, _ name: String, _ children: [LayerNode<Layer>]) -> LayerNode<Layer> {
        LayerNode(id: id, name: name, children: children, payload: Layer(holdsChildren: true))
    }

    /// Back to front: Background, Group (Child), Shadow (locked), Ball, Hero.
    static let small = LayerTree([
        leaf("background", "Background"), group("group", "Group", [leaf("child", "Child")]),
        leaf("shadow", "Shadow", locked: true), leaf("ball", "Ball"), leaf("hero", "Hero"),
    ])

    /// 300 nodes: ten groups of 29 layers.
    static let large = LayerTree((1...10).map { g in
        group("group-\(g)", "Group \(g)", (1...29).map { leaf("layer-\(g)-\($0)", "Layer \(g).\($0)") })
    })

    /// The grid pages' cells: "Item 1" to "Item `count`", no pixels, so each
    /// draws the placeholder fill under its caption.
    static func items(_ count: Int) -> [ThumbnailItem<Int>] {
        (1...max(count, 1)).map { ThumbnailItem(id: $0, caption: "Item \($0)") }
    }

    /// A grid selection's log line: its ids, sorted, joined by commas.
    static func picked(_ selection: Set<Int>) -> String {
        selection.isEmpty ? "none" : selection.sorted().map(String.init).joined(separator: ",")
    }

    /// Where SwiftUI's move to `offset` lands `source` in the order without it.
    static func target(from source: Int, offset: Int) -> Int { offset > source ? offset - 1 : offset }
}

/// The last log line on screen; the whole log in its accessibility value.
private struct GalleryListLog: View {
    let lines: [String]

    var body: some View {
        let text = lines.joined(separator: "\n")
        Text(lines.last ?? "Nothing yet")
            .font(SuiteFont.caption)
            .foregroundStyle(SuiteColor.secondaryText)
            .lineLimit(1)
            .accessibilityLabel(text)
            .accessibilityValue(text)
            .accessibilityIdentifier("suite.gallery.log")
    }
}

/// The `window` page: a SuiteWindow that never recurses into the gallery.
private struct GalleryWindowPage: View {
    @Environment(\.galleryRequest) private var request
    @State private var order = ["hero", "ball", "shadow", "group"]
    @State private var names = ["hero": "Hero", "ball": "Ball", "shadow": "Shadow", "group": "Group", "child": "Child"]
    @State private var hidden: Set<String> = []
    @State private var locked: Set<String> = []
    @State private var open: Set<String> = []
    @State private var selection: String?
    @State private var log: [String] = []

    private var editing: any ListEditing { request?.fakes == true ? FakeListEditing() : SuiteListEditing() }

    var body: some View {
        SuiteWindow(
            galleryPage: nil, title: "Window", sections: sections, selection: selection,
            onSelect: { selection = $0 }, onToggle: toggle, onMove: move, onRename: rename,
            contextActions: menu, expanded: open, onExpand: expand,
            content: {
                VStack(alignment: .leading, spacing: SuiteSpacing.s) {
                    Text(selection.flatMap { names[$0] } ?? "No Selection").font(SuiteFont.title)
                    GalleryListLog(lines: log)
                }
                .padding(SuiteSpacing.m)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            },
            inspector: {
                EmptyStateView("No Selection", systemImage: "square.dashed", message: "Nothing to inspect yet.")
            })
    }

    private var sections: [SidebarSection] {
        [SidebarSection(id: "layers", title: "Layers", items: order.map(item)),
         SidebarSection(id: "pages", title: "Pages", items: [])]
    }

    private func item(_ id: String) -> SidebarItem {
        let name = names[id] ?? id
        let children = id == "group" ? [item("child")] : []
        return SidebarItem(
            id: id, title: name, systemImage: children.isEmpty ? "square" : "folder",
            toggles: [
                SidebarToggle(id: "eye", title: hidden.contains(id) ? "Show \(name)" : "Hide \(name)",
                              onSymbol: "eye", offSymbol: "eye.slash", isOn: !hidden.contains(id)),
                SidebarToggle(id: "lock", title: locked.contains(id) ? "Unlock \(name)" : "Lock \(name)",
                              onSymbol: "lock", offSymbol: "lock.open", isOn: locked.contains(id)),
            ],
            children: children, isDimmed: hidden.contains(id) || locked.contains(id))
    }

    private func write(_ line: String) {
        log.append(line)
        if log.count > 40 { log.removeFirst(log.count - 40) }
    }

    private func toggle(_ id: String, _ part: String) {
        if part == "eye" {
            if hidden.remove(id) == nil { hidden.insert(id) }
            write("toggle eye \(id)")
        } else {
            if locked.remove(id) == nil { locked.insert(id) }
            write("toggle lock \(id) \(locked.contains(id) ? "locked" : "unlocked")")
        }
    }

    private func move(_ section: String, _ sources: IndexSet, _ offset: Int) {
        guard let source = sources.first, order.indices.contains(source) else { return }
        let id = order[source]
        let index = GalleryLists.target(from: source, offset: offset)
        order = editing.reordered(order, moving: id, to: index)
        write("move \(id) \(index)")
    }

    private func rename(_ id: String, _ name: String) -> String? {
        if name == "Taken" { return GalleryLists.taken }
        names[id] = name
        write("rename \(id) \(name)")
        return nil
    }

    private func menu(_ id: String) -> [ToolbarAction] {
        [ToolbarAction("Duplicate", systemImage: "plus.square.on.square") { write("menu duplicate \(id)") },
         ToolbarAction("Delete", systemImage: "trash", unavailableHelp: GalleryLists.deleteHelp)]
    }

    private func expand(_ id: String, _ isOpen: Bool) {
        if isOpen { open.insert(id) } else { open.remove(id) }
        write("\(isOpen ? "open" : "close") \(id)")
    }
}

/// The `layers` pages: LayerTreeList over the page's own tree, every container open.
private struct GalleryLayersPage: View {
    @State private var tree: LayerTree<GalleryLists.Layer>
    @State private var open: Set<String>
    @State private var log: [String] = []

    init(tree: LayerTree<GalleryLists.Layer>) {
        _tree = State(initialValue: tree)
        _open = State(initialValue: GalleryEditorKernel.allOpen(tree))
    }

    var body: some View {
        let rows = tree.rows(expanded: open)
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            if rows.isEmpty {
                EmptyStateView("No layers yet.", systemImage: "square.3.layers.3d", message: "Add a layer to see it here.")
            } else {
                LayerTreeList(rows: rows, childCount: { tree.node($0)?.children.count ?? 0 }, onAction: apply)
                    .frame(maxWidth: SuiteSize.editorPanelWidth, maxHeight: .infinity)
            }
            GalleryListLog(lines: log)
        }
        .padding(SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func apply(_ action: LayerTreeAction) {
        var wasOpen = false
        switch action {
        case .disclose(let id):
            wasOpen = open.contains(id)
            if wasOpen { open.remove(id) } else { open.insert(id) }
        case .toggleHidden(let id), .toggleLocked(let id):
            let hides = action == .toggleHidden(id)
            _ = tree.update(id) { node in
                if hides { node.isHidden.toggle() } else { node.isLocked.toggle() }
            }
        case .move(let drop):
            try? tree.move(drop.id, into: drop.parent, at: drop.index)
        }
        log.append(GalleryEditorKernel.line(action, open: wasOpen))
        if log.count > 40 { log.removeFirst(log.count - 40) }
    }
}

/// The `grid` pages: ThumbnailGrid over `count` placeholder cells.
private struct GalleryGridPage: View {
    @Environment(\.galleryRequest) private var request
    private let items: [ThumbnailItem<Int>]
    @State private var selection: Set<Int> = []
    @State private var log: [String] = []

    init(count: Int) {
        items = GalleryLists.items(count)
    }

    private var selecting: any GridSelecting { request?.fakes == true ? FakeGridSelecting() : SuiteGridSelecting() }

    var body: some View {
        let side = SuiteSize.nodeSize.width
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            ThumbnailGrid(
                items, cellSize: CGSize(width: side, height: side * 3 / 4), selection: selection,
                onSelectionChange: { next in
                    selection = next
                    log.append(GalleryLists.picked(next))
                },
                onOpen: { log.append("open \($0)") },
                cellIdentifierPrefix: "suite.grid.", selecting: selecting)
            GalleryListLog(lines: log)
                .padding(.horizontal, SuiteSpacing.m)
        }
        .padding(.bottom, SuiteSpacing.m)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
