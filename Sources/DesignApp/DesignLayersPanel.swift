// DesignLayersPanel.swift: the Layers tab of Design's panel. One List in the
// small source-list style: the file's pages, with Add Page and Delete Page in
// a SidebarActionRow under them (`design.page.add`, `design.page.delete`,
// each disabled with the Model's reason), then the current page's layer tree,
// frontmost at the top (`frontToBack`), or a hint when the page is empty or no
// file is open, then SuiteUI's LayerActionBar: Group, Duplicate, Delete and fx
// (waiting on layer styles), `design.layers.bar.<part>`. A layer row's context
// menu (built on open, for the rows it opened on) holds Duplicate, Delete,
// Group, Ungroup and Arrange's four steps. Bar and menu items are the Edit and
// Object menus' catalog specs on the same state (`ToolbarAction(spec, on:)`),
// so enablement and reasons match; a row outside the selection reads as selected in its menu,
// and a pick selects it first.
// Selection runs through the List, so arrow keys and type-select move through
// pages and layers; the highlighted rows are the selected layers, or the
// current page when no layer is. Shift-click toggles one layer (#413). The
// current page always carries a checkmark. A layer with children is a
// DisclosureGroup whose expanded state is the workspace's (`isExpanded`, sent
// back as `.setExpanded`; collapsing the selection's parent selects it, #121).
// Each layer is SuiteUI's SidebarRow with eye and lock toggles
// (`layerToggles`), one undo step a click (#45); a layer hidden by itself or a
// group reads dimmed (SuiteColor.textSecondary), and a child shows its
// group's state in its toggles. Each row carries `design.layer.<id>`: a leaf
// row is a container with its toggles inside, and a group's row, its
// disclosure's label, combines into one checkbox whose identifier is the
// row's (#2410; a `.contain` label loses it, #3300 to #3304), so the group's
// eye stays a plain click at the shared toggle column (#53). A page row is a
// container `design.page.row.<id>` (journeys count pages by identifier,
// #1451). While the list has focus, Edit > Cut, Copy and Paste send `.cut`,
// `.copy` and `.paste`. A double-click on a layer's name renames it in place
// (`.renameLayer`, one "Rename Layer" step). Dragging a layer row draws an
// insertion line above or below the row under the pointer, or tints a frame
// or group it would go into (`layerDropLine`, nothing for a refused drop),
// through the system drag (`onDrag` and a `DropDelegate` per row, #3427); the
// line is the panel's own state and the dragged id and row heights sit in a
// box nothing observes, so a drag never runs the editor's body. The drop
// sends one `.moveLayer` (`layerDrop`). The rename refusal
// (`design.layers.rename-refusal`) is the panel's own state. No scroll
// indicators, so no legacy scroller reads as an unlabelled button (#2552).
// Values in, intents out.
import DesignModel
import SuiteUI
import SwiftUI
import UniformTypeIdentifiers

struct DesignLayersPanel: View {
    let model: DesignWorkspace
    let perform: DesignPerform
    /// Seeds the insertion line, so a snapshot can show a drag in flight; the app passes none.
    var seededLine: DesignLayerDropLine? = nil
    /// The layer row being renamed, its draft and the last refusal; the panel's own state.
    @State private var rename = DesignRenameState()
    /// Where a dragged layer would land; nil with no drag, or over a row that refuses it.
    @State private var dropLine: DesignLayerDropLine?
    /// The dragged layer and the rows' frames; a box SwiftUI doesn't watch.
    @State private var rowFrames = DesignLayerRowFrames()

    var body: some View {
        List(selection: selection) {
            Section {
                ForEach(model.pages) { page in
                    DesignPageLabel(page: page, isCurrent: page.id == model.selectedPageID).tag(page.id)
                }
                // A row, not the section header: a sidebar header hides its buttons from accessibility.
                // The accessory-bar button pads its glyph on top of the row's own inset; pulling the row
                // back by that padding puts the + glyph on the page rows' symbol column (#1386).
                SidebarActionRow(Self.pageCommands(model, perform))
                    .padding(.leading, -SuiteInset.barButton.leading)
            } header: {
                header("Pages")
            }
            Section {
                if let nodes = model.selectedPage?.nodes, !nodes.isEmpty {
                    DesignLayerTree(nodes: nodes, model: model, perform: perform, drag: layerDrag)
                } else {
                    let notes = Self.emptyNotes(isOpen: model.isOpen)
                    ForEach(notes.indices, id: \.self) { line in
                        InspectorNote(notes[line], identifier: line == 0 ? "design.layers.empty" : "design.layers.empty.\(line)")
                    }
                }
                if let refusal = rename.refusal {
                    InspectorNote(refusal, identifier: DesignRenameState.refusalID)
                }
                LayerActionBar(Self.bar(DesignMenu(model: model, perform: perform)))
                    .padding(.leading, -SuiteInset.barButton.leading)
            } header: {
                header("Layers")
            }
        }
        // The source-list style draws the selection on a row inside a disclosure; the plain one doesn't.
        .listStyle(.sidebar)
        .environment(\.sidebarRowSize, .small)
        .scrollContentBackground(.hidden)
        // No scroller: on `crowd`'s 2,000 layers a legacy scroller's page area is an unnamed button
        // to the app audit (#2552), as it was in the inspector (#2455).
        .scrollIndicators(.never)
        .font(SuiteFont.inspectorLabel)
        .layerContextMenu(forSelection: { Self.rowMenu(DesignMenu(model: model, perform: perform), rows: $0) })
        .accessibilityIdentifier("design.layers")
        .designPasteboardCommands(model, perform)
    }

    /// The rows' drag: the pointer `y` points down row `rowID` moves the line only when it changes,
    /// leaving a row clears its line, and the drop at `y` sends the one move the line there shows.
    /// The drop works out its own line rather than reading the last hover's, so a release that
    /// lands before the hover is reported still moves the layer (#3556).
    private var layerDrag: DesignLayerDrag {
        DesignLayerDrag(line: dropLine ?? seededLine, frames: rowFrames, changed: { rowID, y in
            let line = dropLine(over: rowID, y: y)
            if line != dropLine { dropLine = line }
        }, exited: { rowID in
            if dropLine?.rowID == rowID { dropLine = nil }
        }, dropped: { rowID, y in
            defer {
                rowFrames.dragged = nil
                if dropLine != nil { dropLine = nil }
            }
            guard let id = rowFrames.dragged, let line = dropLine(over: rowID, y: y),
                  let target = model.layerDrop(id, onto: rowID, line.position) else { return false }
            perform(.moveLayer(id, parent: target.parentID, index: target.index))
            return true
        })
    }

    /// The line the dragged layer shows `y` points down row `rowID`, or nil when the Model refuses that drop.
    private func dropLine(over rowID: String, y: CGFloat) -> DesignLayerDropLine? {
        rowFrames.dragged.flatMap { id in
            rowFrames.frames[rowID].flatMap { frame in
                model.layerDropLine(id, over: rowID, y: Double(y), height: Double(frame.height))
            }
        }.map { DesignLayerDropLine(rowID: rowID, position: $0) }
    }

    private func header(_ title: String) -> some View {
        Text(title).foregroundStyle(SuiteColor.textSecondary)
    }

    /// The highlighted rows: every selected layer, or the current page when no layer is.
    private var highlighted: Set<String> {
        model.selectedNodeIDs.isEmpty ? Set([model.selectedPageID].compactMap { $0 }) : Set(model.selectedNodeIDs)
    }

    /// Picking a row selects that page or layer; clicking empty space deselects the layer. A
    /// Command-click toggles the rows it changes. A Shift-click is the row's own gesture, which
    /// toggles that one layer, so the List's range extension is ignored.
    private var selection: Binding<Set<String>> {
        Binding(
            get: { highlighted },
            set: { ids in
                guard !DesignModifiers.current.contains(.shift) else { return }
                if ids.count == 1, let id = ids.first {
                    perform(.select(id))
                } else if ids.isEmpty {
                    perform(.deselect)
                } else {
                    for id in ids.symmetricDifference(highlighted) { perform(.toggleSelect(id)) }
                }
            })
    }

    /// The Layers section's lines when the page has no layers, one note each: a list row doesn't
    /// grow to wrap a note, so each line is short enough to fit the panel on its own.
    nonisolated static func emptyNotes(isOpen: Bool) -> [String] {
        isOpen ? ["No layers on this page.", "Draw a frame with the Frame tool (F)."] : ["No file open."]
    }

    /// The bar's commands: catalog id, symbol, id part and intent.
    static let barCommands: [(id: String, symbol: String, part: String, intent: DesignIntent)] = [
        ("object.group", "rectangle.3.group", "group", .command(.group)),
        ("edit.duplicate", "plus.square.on.square", "duplicate", .command(.duplicate)),
        ("edit.delete", "trash", "delete", .deleteSelection),
    ]

    /// A row menu's commands: catalog id, symbol and intent, Arrange's four steps last.
    static let rowCommands: [(id: String, symbol: String, intent: DesignIntent)] = [
        ("edit.duplicate", "plus.square.on.square", .command(.duplicate)), ("edit.delete", "trash", .deleteSelection),
        ("object.group", "rectangle.3.group", .command(.group)), ("object.ungroup", "rectangle.dashed", .command(.ungroup)),
    ] + DesignArrangeStep.allCases.map { (DesignMenuState.objectID($0.title), $0.systemImage, .command(.arrange($0))) }

    /// The bar: each command as its menu item on the selection, then fx, disabled until layer styles land.
    // view-static: main-actor
    static func bar(_ menu: DesignMenu) -> [ToolbarAction] {
        barCommands.map { command in
            ToolbarAction(DesignMenuState.spec(command.id), on: menu.state(), systemImage: command.symbol,
                          identifier: "design.layers.bar." + command.part) { menu.perform(command.intent) }
        } + [LayerActionBar.effects(identifier: "design.layers.bar.fx")]
    }

    /// The context menu for the layer rows `ids` it opened on: the menu items on the selection, or,
    /// for one row outside it, with that row selected, which a pick selects first. None for a page row.
    // view-static: main-actor
    static func rowMenu(_ menu: DesignMenu, rows ids: Set<String>) -> [ToolbarAction] {
        guard !ids.isEmpty, ids.isDisjoint(with: menu.workspace.pages.map(\.id)) else { return [] }
        let outside = ids.count == 1 && !menu.workspace.selectedNodeIDs.contains(ids.first ?? "") ? ids.first : nil
        var state = menu.state()
        if let outside { state.workspace.selectItem(outside) }
        return rowCommands.map { command in
            ToolbarAction(DesignMenuState.spec(command.id), on: state, systemImage: command.symbol) {
                if let outside { menu.perform(.select(outside)) }
                menu.perform(command.intent)
            }
        }
    }

    /// Add Page and Delete Page (the checked page), each disabled with the Model's reason while it
    /// can't run: no file open, or the file's last page. Untagged, so not selectable.
    static func pageCommands(_ model: DesignWorkspace, _ perform: @escaping DesignPerform) -> [ToolbarAction] {
        [
            ToolbarAction(
                "Add Page", systemImage: "plus", unavailableHelp: model.addPageHelp, identifier: "design.page.add"
            ) { perform(.addPage) },
            ToolbarAction(
                "Delete Page", systemImage: "trash", unavailableHelp: model.deletePageHelp,
                identifier: "design.page.delete"
            ) { perform(.deletePage) },
        ]
    }
}

/// The Layers rename's presentation state: the row in rename (nil: none), the name being typed,
/// and the reason the last rename was refused, shown under the layers until the next one. The
/// panel owns it; the row's own field (SidebarRow) holds the draft, and the rename goes out as `.renameLayer`.
struct DesignRenameState: Equatable {
    /// The identifier of the row's name field while it is in rename.
    static let fieldID = "design.layer.rename"
    /// The identifier of the refusal's hint.
    static let refusalID = "design.layers.rename-refusal"

    var rowID: String?
    var draft = ""
    var refusal: String?
}

/// The insertion line: the row it is drawn on and where on it.
struct DesignLayerDropLine: Equatable {
    let rowID: String
    let position: DesignDropPosition
}

/// The layer being dragged, set when its row's drag starts, and each visible layer row's frame,
/// written as rows lay out. A plain box, so a drag starting, a row moving or scrolling re-renders nothing.
@MainActor final class DesignLayerRowFrames {
    var dragged: String?
    var frames: [String: CGRect] = [:]
}

/// What a layer row's drag reads and calls: the current line, the box, and the panel's handlers
/// for the pointer `y` points down a row, the pointer leaving a row, and a drop on one.
struct DesignLayerDrag {
    let line: DesignLayerDropLine?
    let frames: DesignLayerRowFrames
    let changed: @MainActor (String, CGFloat) -> Void
    let exited: @MainActor (String) -> Void
    let dropped: @MainActor (String, CGFloat) -> Bool
}

/// A layer row as a drop target: it reports where over the row the drag is, and the drop.
private struct DesignLayerDropTarget: DropDelegate {
    let rowID: String
    let drag: DesignLayerDrag

    func dropUpdated(info: DropInfo) -> DropProposal? {
        drag.changed(rowID, info.location.y)
        return DropProposal(operation: drag.frames.dragged == nil ? .forbidden : .move)
    }

    func dropExited(info: DropInfo) { drag.exited(rowID) }

    func performDrop(info: DropInfo) -> Bool { drag.dropped(rowID, info.location.y) }
}

/// One page: its symbol and name, with a checkmark on the current page.
private struct DesignPageLabel: View {
    let page: DesignPage
    let isCurrent: Bool

    var body: some View {
        HStack(spacing: SuiteSpacing.xs) {
            Label(page.name, systemImage: "doc")
                .foregroundStyle(Color.primary)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
            if isCurrent {
                Image(systemName: "checkmark")
                    .font(SuiteFont.inspectorMeta)
                    .foregroundStyle(HierarchicalShapeStyle.secondary)  // adapts on the selected row
                    .help("Current page")
                    .accessibilityLabel("Current page")
                    .accessibilityIdentifier("design.current-page")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("design.page.row.\(page.id)")
    }
}

/// The rows of `nodes`, frontmost first, each with its children under a disclosure the workspace expands.
private struct DesignLayerTree: View {
    let nodes: [DesignNode]
    let model: DesignWorkspace
    let perform: DesignPerform
    let drag: DesignLayerDrag

    var body: some View {
        ForEach(nodes.frontToBack) { node in
            if node.children.isEmpty {
                DesignLayerRow(node: node, model: model, perform: perform, drag: drag).tag(node.id)
            } else {
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { model.isExpanded(node.id) }, set: { perform(.setExpanded(node.id, $0)) })
                ) {
                    DesignLayerTree(nodes: node.children, model: model, perform: perform, drag: drag)
                } label: {
                    DesignLayerRow(node: node, model: model, perform: perform, drag: drag, isDisclosureLabel: true)
                        .tag(node.id)
                }
                .tag(node.id)
            }
        }
    }
}

/// One layer: SuiteUI's sidebar row with the kind's symbol, the name (double-click renames it), and
/// the eye and lock toggles; it drags to reorder and draws the insertion line when it is the target.
private struct DesignLayerRow: View {
    let node: DesignNode
    let model: DesignWorkspace
    let perform: DesignPerform
    let drag: DesignLayerDrag
    /// A group's row: its disclosure flattens the label into one checkbox, so the row combines.
    var isDisclosureLabel = false

    var body: some View {
        let id = node.id
        let toggles = model.layerToggles(id)
        let line = drag.line?.rowID == id ? drag.line?.position : nil
        SidebarRow(
            SidebarItem(
                id: id, title: node.name, systemImage: node.kind.systemImage,
                toggles: toggles.map {
                    SidebarToggle(
                        id: $0.flag.rawValue, title: $0.title, onSymbol: $0.onSymbol, offSymbol: $0.offSymbol,
                        isOn: $0.isOn, reserving: $0.symbols)
                }),
            onToggle: { flag in
                if let flag = DesignLayerFlag(rawValue: flag) { perform(.toggleFlag(id, flag)) }
            },
            onRename: { name in perform(.renameLayer(id, name)) }
        )
        .lineLimit(1)
        .truncationMode(.middle)
        .foregroundStyle(model.isHiddenInTree(id) ? SuiteColor.textSecondary : Color.primary)
        .simultaneousGesture(TapGesture().modifiers(.shift).onEnded { perform(.toggleSelect(id)) })
        .background { if line == .into { RoundedRectangle(cornerRadius: SuiteRadius.row).fill(SuiteColor.dragFill) } }
        .overlay(alignment: line == .above ? .top : .bottom) {
            if line == .above || line == .below {
                Rectangle().fill(SuiteColor.accent).frame(height: SuiteSize.insertionLine).accessibilityHidden(true)
            }
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { drag.frames.frames[id] = $0 }
        .onDisappear { drag.frames.frames[id] = nil }
        .onDrag {
            drag.frames.dragged = id
            return NSItemProvider(object: id as NSString)
        }
        .onDrop(of: [.plainText], delegate: DesignLayerDropTarget(rowID: id, drag: drag))
        .accessibilityElement(children: isDisclosureLabel ? .combine : .contain)
        .accessibilityIdentifier("design.layer.\(id)")
    }
}
