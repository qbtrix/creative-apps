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
// A page row is a container identified `design.page.row.<id>` with its checkmark inside: a page name's words sit in its text's value, not
// its label, so journeys count pages by identifier (#1451). The section headers use SuiteColor.textSecondary; the
// sidebar style's own header gray is under 4.5:1. While the list has focus, Edit >
// Cut, Copy and Paste send `.cut`, `.copy` and `.paste` (designPasteboardCommands).
// The rename state (DesignRenameState: the row in rename, the draft, the refusal
// shown as `design.layers.rename-refusal`) is the panel's own. The list shows no
// scroll indicators, as the inspector doesn't, so on a long layer tree no legacy
// scroller reads as an unlabelled button (#2552). Values in, intents out.
import DesignModel
import SuiteUI
import SwiftUI

struct DesignLayersPanel: View {
    let model: DesignWorkspace
    let perform: DesignPerform
    /// The layer row being renamed, its draft and the last refusal; the panel's own state.
    @State private var rename = DesignRenameState()

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
                    DesignLayerTree(nodes: nodes, model: model, perform: perform)
                } else {
                    DesignPanelHint(model.isOpen ? "Nothing on this page yet." : "No file open.")
                }
                if let refusal = rename.refusal {
                    DesignPanelHint(refusal).accessibilityIdentifier(DesignRenameState.refusalID)
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
/// panel owns it; the rename itself goes to the Model as an intent once rows rename (layers-panel L-4).
struct DesignRenameState: Equatable {
    /// The identifier of the row's name field while it is in rename.
    static let fieldID = "design.layer.rename"
    /// The identifier of the refusal's hint.
    static let refusalID = "design.layers.rename-refusal"

    var rowID: String?
    var draft = ""
    var refusal: String?
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
                    .foregroundStyle(SuiteColor.secondaryText)
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

    var body: some View {
        ForEach(nodes.frontToBack) { node in
            if node.children.isEmpty {
                DesignLayerRow(node: node, model: model, perform: perform).tag(node.id)
            } else {
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { model.isExpanded(node.id) }, set: { perform(.setExpanded(node.id, $0)) })
                ) {
                    DesignLayerTree(nodes: node.children, model: model, perform: perform)
                } label: {
                    DesignLayerRow(node: node, model: model, perform: perform, isDisclosureLabel: true).tag(node.id)
                }
                .tag(node.id)
            }
        }
    }
}

/// One layer: SuiteUI's sidebar row with the kind's symbol, the name, and the eye and lock toggles.
private struct DesignLayerRow: View {
    let node: DesignNode
    let model: DesignWorkspace
    let perform: DesignPerform
    /// A group's row: its disclosure flattens the label into one checkbox, so the row combines.
    var isDisclosureLabel = false

    var body: some View {
        let id = node.id
        let toggles = model.layerToggles(id)
        SidebarRow(
            SidebarItem(
                id: id, title: node.name, systemImage: node.kind.systemImage,
                toggles: toggles.map {
                    SidebarToggle(
                        id: $0.flag.rawValue, title: $0.title, onSymbol: $0.onSymbol, offSymbol: $0.offSymbol,
                        isOn: $0.isOn)
                }),
            onToggle: { flag in
                if let flag = DesignLayerFlag(rawValue: flag) { perform(.toggleFlag(id, flag)) }
            }
        )
        .lineLimit(1)
        .truncationMode(.middle)
        .foregroundStyle(model.isHiddenInTree(id) ? SuiteColor.textSecondary : Color.primary)
        .simultaneousGesture(TapGesture().modifiers(.shift).onEnded { perform(.toggleSelect(id)) })
        .accessibilityElement(children: isDisclosureLabel ? .combine : .contain)
        .accessibilityIdentifier("design.layer.\(id)")
    }
}
