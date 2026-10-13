// DesignLayersPanel.swift: the Layers tab of Design's panel. Pages on top (one
// row per page, with Add Page and Delete Page), then the selected page's layer
// tree as rows indented by depth. A row with children has a disclosure
// chevron: a plain borderless button in a fixed-width slot, drawn the same
// way expanded or collapsed (chevron.down or chevron.right), so only the
// shape tells the states apart. Rows without children keep an empty slot so
// names line up. The selected page or layer sits on the accent well; a hidden
// layer reads dimmed with an eye-slash mark and a locked one carries a lock.
// A plain ScrollView of rows, not a List, so snapshots draw it. Values in,
// intents out.
import DesignModel
import SuiteUI
import SwiftUI

struct DesignLayersPanel: View {
    let model: DesignWorkspace
    let perform: DesignPerform

    var body: some View {
        let rows = model.layerRows
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                InspectorSection("Pages") {
                    ForEach(model.pages) { page in
                        DesignPageRow(page: page, isSelected: page.id == model.selectedPageID, perform: perform)
                    }
                    pageActions
                }
                InspectorSection("Layers") {
                    if rows.isEmpty {
                        DesignPanelHint("Nothing on this page yet.")
                    }
                    ForEach(rows) { row in
                        DesignLayerRow(
                            row: row, isSelected: row.id == model.selectedNodeID, isExpanded: model.isExpanded(row.id),
                            perform: perform)
                    }
                }
            }
        }
        .accessibilityIdentifier("design.layers")
    }

    /// Add Page and Delete Page; the last page can't be deleted.
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
        .padding(.horizontal, SuiteSpacing.xs)
    }
}

/// A full-width row at the inspector's row height that sits on the accent well while selected.
private struct DesignRowFrame<Content: View>: View {
    private let isSelected: Bool
    private let content: Content

    init(isSelected: Bool, @ViewBuilder content: () -> Content) {
        self.isSelected = isSelected
        self.content = content()
    }

    var body: some View {
        content
            .font(SuiteFont.inspectorLabel)
            .padding(.horizontal, SuiteSpacing.s)
            .frame(maxWidth: .infinity, minHeight: SuiteSize.inspectorRow, alignment: .leading)
            .background(isSelected ? SuiteColor.selectedWell : Color.clear)
    }
}

/// One page: its symbol and name. Clicking selects the page and clears the layer selection.
private struct DesignPageRow: View {
    let page: DesignPage
    let isSelected: Bool
    let perform: DesignPerform

    var body: some View {
        DesignRowFrame(isSelected: isSelected) {
            Button {
                perform(.select(page.id))
            } label: {
                HStack(spacing: SuiteSpacing.xs) {
                    Image(systemName: "doc")
                        .foregroundStyle(SuiteColor.secondaryText)
                        .frame(width: SuiteSpacing.l)
                        .accessibilityHidden(true)
                    Text(page.name).lineLimit(1).truncationMode(.middle)
                    Spacer(minLength: 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(page.name)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }
}

/// One layer: the disclosure slot, the kind's symbol, the name and the hidden and locked marks.
private struct DesignLayerRow: View {
    let row: DesignRow
    let isSelected: Bool
    let isExpanded: Bool
    let perform: DesignPerform

    private var node: DesignNode { row.node }

    /// "Hidden", "Locked" or both, for VoiceOver; empty for a plain layer.
    private var stateText: String {
        [node.isHidden ? "Hidden" : nil, node.isLocked ? "Locked" : nil].compactMap { $0 }.joined(separator: ", ")
    }

    var body: some View {
        DesignRowFrame(isSelected: isSelected) {
            HStack(spacing: SuiteSpacing.xs) {
                disclosure
                Button {
                    perform(.select(node.id))
                } label: {
                    HStack(spacing: SuiteSpacing.xs) {
                        Image(systemName: node.kind.systemImage)
                            .foregroundStyle(SuiteColor.secondaryText)
                            .frame(width: SuiteSpacing.l)
                            .accessibilityHidden(true)
                        Text(node.name)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .foregroundStyle(node.isHidden ? SuiteColor.secondaryText : Color.primary)
                        Spacer(minLength: 0)
                        if node.isHidden { mark("eye.slash", "Hidden") }
                        if node.isLocked { mark("lock", "Locked") }
                    }
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(node.name)
                .accessibilityValue(stateText)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
            .padding(.leading, SuiteSpacing.l * CGFloat(row.depth))
        }
    }

    /// The expand and collapse chevron, or an empty slot of the same width for a layer with no children.
    @ViewBuilder
    private var disclosure: some View {
        if node.children.isEmpty {
            Color.clear.frame(width: SuiteSpacing.l, height: SuiteSize.inspectorRow)
        } else {
            let verb = isExpanded ? "Collapse" : "Expand"
            Button {
                perform(.toggleExpanded(node.id))
            } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(SuiteFont.inspectorMeta)
                    .foregroundStyle(SuiteColor.secondaryText)
                    .frame(width: SuiteSpacing.l, height: SuiteSize.inspectorRow)
                    .contentShape(.rect)
            }
            .buttonStyle(.borderless)
            .help("\(verb) \(node.name)")
            .accessibilityLabel("\(verb) \(node.name)")
        }
    }

    private func mark(_ systemImage: String, _ title: String) -> some View {
        Image(systemName: systemImage)
            .font(SuiteFont.inspectorMeta)
            .foregroundStyle(SuiteColor.secondaryText)
            .help(title)
    }
}
