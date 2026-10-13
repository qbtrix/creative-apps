// DesignLayersPanel.swift: the Layers tab of Design's panel. One List in the
// small source-list style: the file's pages, with Add Page and Delete Page in
// the Pages header, then the current page's layer tree. Selection runs through
// the List, so arrow keys and type-select move through pages and layers; the
// highlighted row is the selected layer, or the current page when no layer is.
// The current page always carries a checkmark, so the page you are editing,
// the one Delete Page removes, stays marked while a layer holds the highlight.
// A layer with children is a DisclosureGroup whose expanded state is the
// workspace's (`isExpanded`), sent back as `.setExpanded`, so collapsing the
// parent of the selection selects the parent (#121). A hidden layer reads
// dimmed with an eye-slash mark and a locked one carries a lock. Values in,
// intents out.
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
            } header: {
                HStack(spacing: 0) {
                    Text("Pages")
                    Spacer(minLength: 0)
                    pageActions
                }
            }
            Section("Layers") {
                if let nodes = model.selectedPage?.nodes, !nodes.isEmpty {
                    DesignLayerTree(nodes: nodes, model: model, perform: perform)
                } else {
                    DesignPanelHint("Nothing on this page yet.")
                }
            }
        }
        // The source-list style draws the selection on a row inside a disclosure; the plain one doesn't.
        .listStyle(.sidebar)
        .environment(\.sidebarRowSize, .small)
        .scrollContentBackground(.hidden)
        .font(SuiteFont.inspectorLabel)
        .accessibilityIdentifier("design.layers")
    }

    /// Picking a row selects that page or layer; clicking empty space deselects the layer.
    private var selection: Binding<String?> {
        Binding(
            get: { model.selectedNodeID ?? model.selectedPageID },
            set: { id in
                if let id { perform(.select(id)) } else { perform(.deselect) }
            })
    }

    /// Add Page and Delete Page (the checked page); the last page can't be deleted.
    private var pageActions: some View {
        HStack(spacing: 0) {
            EditorBarItem(ToolbarAction("Add Page", systemImage: "plus") { perform(.addPage) }, showsTitle: false)
            EditorBarItem(
                ToolbarAction(
                    "Delete Page", systemImage: "trash",
                    unavailableHelp: model.canDeletePage ? nil : "A file keeps at least one page.") {
                    perform(.deletePage)
                }, showsTitle: false)
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

/// The rows of `nodes`, back to front, each with its children under a disclosure the workspace expands.
private struct DesignLayerTree: View {
    let nodes: [DesignNode]
    let model: DesignWorkspace
    let perform: DesignPerform

    var body: some View {
        ForEach(nodes) { node in
            if node.children.isEmpty {
                DesignLayerLabel(node: node).tag(node.id)
            } else {
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { model.isExpanded(node.id) }, set: { perform(.setExpanded(node.id, $0)) })
                ) {
                    DesignLayerTree(nodes: node.children, model: model, perform: perform)
                } label: {
                    DesignLayerLabel(node: node).tag(node.id)
                }
                .tag(node.id)
            }
        }
    }
}

/// One layer: the kind's symbol, the name and the hidden and locked marks.
private struct DesignLayerLabel: View {
    let node: DesignNode

    var body: some View {
        HStack(spacing: SuiteSpacing.xs) {
            Label(node.name, systemImage: node.kind.systemImage)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundStyle(node.isHidden ? SuiteColor.secondaryText : Color.primary)
            Spacer(minLength: 0)
            if node.isHidden { mark("eye.slash", "Hidden") }
            if node.isLocked { mark("lock", "Locked") }
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue(
            [node.isHidden ? "Hidden" : nil, node.isLocked ? "Locked" : nil].compactMap { $0 }.joined(separator: ", "))
    }

    private func mark(_ systemImage: String, _ title: String) -> some View {
        Image(systemName: systemImage)
            .font(SuiteFont.inspectorMeta)
            .foregroundStyle(SuiteColor.secondaryText)
            .help(title)
            .accessibilityLabel(title)
    }
}
