// DesignLayersPanel.swift: the Layers tab of Design's panel. One List in the
// small source-list style: the file's pages, with Add Page and Delete Page in
// a row under them, then the current page's layer tree, frontmost layer at the
// top (`frontToBack`; the document keeps paint order). Selection runs through
// the List, so arrow keys and type-select move through pages and layers; the
// highlighted rows are the selected layers, or the current page when no layer is.
// Shift-click adds a layer or takes it out, the way it does on the canvas: the
// list's change goes to the workspace with the Shift key (`selectRows`), which
// toggles only the clicked row and turns away a locked or hidden one.
// The current page always carries a checkmark, so the page you are editing,
// the one Delete Page removes, stays marked while a layer holds the highlight.
// A layer with children is a DisclosureGroup whose expanded state is the
// workspace's (`isExpanded`), sent back as `.setExpanded`, so collapsing the
// parent of the selection selects the parent (#121). Each layer is SuiteUI's
// SidebarRow with an eye and a lock toggle (`layerToggles`); a click flips
// that layer's own flag, one undo step (#45). A layer hidden by itself or by
// a group around it reads dimmed, and a child of a hidden or locked group
// shows the group's state in its toggles. Each row carries the identifier
// `design.layer.<id>`: a leaf row is a container with its toggles inside, and a
// group's row, its disclosure's label, reads as one checkbox, so the identifier
// is what names it. The section headers use SuiteColor.textSecondary; the
// sidebar style's own header gray is under 4.5:1. Values in, intents out.
import DesignModel
import SuiteUI
import SwiftUI

struct DesignLayersPanel: View {
    let model: DesignWorkspace
    let perform: DesignPerform

    var body: some View {
        List(selection: selection) {
            Section {
                ForEach(model.pages) { page in
                    DesignPageLabel(page: page, isCurrent: page.id == model.selectedPageID).tag(page.id)
                }
                // A row, not the section header: a sidebar header hides its buttons from accessibility.
                pageActions
            } header: {
                header("Pages")
            }
            Section {
                if let nodes = model.selectedPage?.nodes, !nodes.isEmpty {
                    DesignLayerTree(nodes: nodes, model: model, perform: perform)
                } else {
                    DesignPanelHint("Nothing on this page yet.")
                }
            } header: {
                header("Layers")
            }
        }
        // The source-list style draws the selection on a row inside a disclosure; the plain one doesn't.
        .listStyle(.sidebar)
        .environment(\.sidebarRowSize, .small)
        .scrollContentBackground(.hidden)
        .font(SuiteFont.inspectorLabel)
        .accessibilityIdentifier("design.layers")
    }

    private func header(_ title: String) -> some View {
        Text(title).foregroundStyle(SuiteColor.textSecondary)
    }

    /// Picking a row selects that page or layer, Shift-click toggles a layer, and clicking empty
    /// space deselects the layers.
    private var selection: Binding<Set<String>> {
        Binding(
            get: { model.selectedNodeIDs.isEmpty ? Set(model.selectedPageID.map { [$0] } ?? []) : Set(model.selectedNodeIDs) },
            set: { perform(.selectRows($0, shift: DesignModifiers.current.contains(.shift))) })
    }

    /// Add Page and Delete Page (the checked page); the last page can't be deleted. Untagged, so not selectable.
    private var pageActions: some View {
        HStack(spacing: 0) {
            EditorBarItem(ToolbarAction("Add Page", systemImage: "plus") { perform(.addPage) }, showsTitle: false)
            EditorBarItem(
                ToolbarAction(
                    "Delete Page", systemImage: "trash",
                    unavailableHelp: model.canDeletePage ? nil : "A file keeps at least one page.") {
                    perform(.deletePage)
                }, showsTitle: false)
            Spacer(minLength: 0)
        }
    }
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
                    DesignLayerRow(node: node, model: model, perform: perform).tag(node.id)
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
        .foregroundStyle(model.isHiddenInTree(id) ? SuiteColor.secondaryText : Color.primary)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("design.layer.\(id)")
    }
}
