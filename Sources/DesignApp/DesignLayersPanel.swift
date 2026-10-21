// DesignLayersPanel.swift: the Layers tab of Design's panel. One List in the
// small source-list style: the file's pages, with Add Page and Delete Page in
// a SidebarActionRow under them (`design.page.add`, `design.page.delete`;
// each disabled with the Model's reason while it can't run),
// its first glyph on the page rows' symbol column,
// then the current page's layer tree (a hint when the page is empty or no file
// is open), frontmost layer at the top
// (`frontToBack`; the document keeps paint order). Selection runs through
// the List, so arrow keys and type-select move through pages and layers; the
// highlighted rows are the selected layers, or the current page when no layer is.
// Shift-click on a layer row adds it to the selection or takes it out (#413).
// The current page always carries a checkmark, so the page you are editing,
// the one Delete Page removes, stays marked while a layer holds the highlight.
// A layer with children is a DisclosureGroup whose expanded state is the
// workspace's (`isExpanded`), sent back as `.setExpanded`, so collapsing the
// parent of the selection selects the parent (#121). Each layer is SuiteUI's
// SidebarRow with an eye and a lock toggle (`layerToggles`); a click flips
// that layer's own flag, one undo step (#45). A layer hidden by itself or by
// a group around it reads dimmed (SuiteColor.textSecondary, which keeps 4.5:1
// on a highlighted row), and a child of a hidden or locked group
// shows the group's state in its toggles. Each row carries the identifier
// `design.layer.<id>`: a leaf row is a container with its toggles inside, and a
// group's row, its disclosure's label, reads as one checkbox. That checkbox takes
// its identifier from the label's elements (its toggles' ids, joined), so the
// label combines into one element first and the identifier is the row's (#2410).
// A `.contain` label loses that identifier (#3195's journeys, #3300 to #3304), so the
// group's eye stays a plain click at the toggle column, which every row shares (#53).
// A page row is a container identified `design.page.row.<id>` with its checkmark inside: a page name's words sit in its text's value, not
// its label, so journeys count pages by identifier (#1451). The section headers use SuiteColor.textSecondary; the
// sidebar style's own header gray is under 4.5:1. While the list has focus, Edit >
// Cut, Copy and Paste send `.cut`, `.copy` and `.paste` (designPasteboardCommands).
// A double-click on a layer's name renames it in place (SidebarRow's rename
// field), sent as `.renameLayer`, one "Rename Layer" step; SidebarRow drops an
// empty or unchanged name. Dragging a layer row draws an insertion line above or
// below the row under the pointer, or tints a frame or group the layer would
// go into (`layerDropLine`, which shows nothing for a drop the Model refuses).
// The drag is the system's (`onDrag` on each row, a `DropDelegate` on each row):
// a gesture of the row's own inside the List never saw the pointer move once the
// list's table took the press (#3427). The line is the panel's own state, written
// only when it moves, and the dragged id and the rows' heights sit in a box
// nothing observes, so a drag never runs the editor's body; the drop sends one
// `.moveLayer` (`layerDrop`), one "Move Layer" step. A page
// with no layers says so and points at the Frame tool. The rename refusal state
// (DesignRenameState, `design.layers.rename-refusal`) is the panel's own. The list shows no
// scroll indicators, as the inspector doesn't, so on a long layer tree no legacy
// scroller reads as an unlabelled button (#2552). Values in, intents out.
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
