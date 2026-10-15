// HaloLayerList.swift: the selected composition's layers, top first, flush
// under the inspector's Layers section (which draws the title, so the list has
// none), as an editable list (layer-panel, #770). It is a system List, since
// drag to reorder (`.onMove`) needs one, with its chrome taken off so the rows
// look as W0's plain stack did: the plain style, no row insets, separators or
// row backgrounds, no content background, and no List selection (a sidebar
// List added its own selection inset and grey highlight). Each row spans the
// section's full width, the same edges as the Composition rows, with its icon
// and name SuiteSpacing.m inside, and SuiteSpacing.xs under it. The List
// doesn't scroll inside the inspector's scroll view: its height is its rows'
// (SuiteSize.studioRow + SuiteSpacing.xs each, one studioRow more while a
// refusal shows). Each row is a plain Button around SuiteUI's SidebarRow: a
// click sends `selectLayer`, a double-click on the name renames it on the row
// (SidebarRow trims the name and drops an empty one, then the row sends
// `renameLayer(id, name)`). A drag sends `moveLayer(id, to:)`, the index from
// HaloProject.moveTarget, so the view does no offset math; Delete (⌫) sends
// `deleteLayer`. The selected row draws the design.md Selected state: the
// `stateSelected` tint (SuiteColor.selectedTint) with a 1 pt accent outline at
// SuiteRadius.row and a semibold name. Names are in primary ink; only the
// selected row's kind icon takes the accent, the rest use secondary ink
// (HaloLayerLabelStyle styles SidebarRow's label from outside; SuiteUI is not
// restyled). A row is the control `halo.layer.row.<layer id>`
// (HaloControls.swift) and carries its layer id as its tag; its tooltip and
// VoiceOver value name the kind ("Solid layer", from HaloModel). A refused
// rename shows its message under the row `refusal.control` names, in W0's
// HaloRefusalCaption (`halo.layer.refusal`). A composition with no layers
// shows "No layers yet. Add one from Layer > New." (`halo.layer.empty`).
// The list is `halo.layer.list`. Values in, commands out.
import HaloModel
import SuiteUI
import SwiftUI

struct HaloLayerList: View {
    let model: HaloProject
    var perform: @MainActor (HaloCommand) -> Void = { _ in }

    var body: some View {
        let layers = model.selectedComposition?.layers ?? []
        if layers.isEmpty {
            Label("No layers yet. Add one from Layer > New.", systemImage: "square.stack.3d.up")
                .font(SuiteFont.caption)
                .foregroundStyle(SuiteColor.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("halo.layer.empty")
        } else {
            List {
                ForEach(layers) { layer in
                    HaloLayerRow(
                        layer: layer, selected: layer.id == model.selectedLayerID,
                        refusal: refusal(for: layer), perform: perform)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }
                .onMove { source, offset in move(source, to: offset, in: layers) }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .environment(\.defaultMinListRowHeight, SuiteSize.studioRow)
            .frame(maxWidth: .infinity)
            .frame(height: height(rows: layers.count, refused: layers.contains { refusal(for: $0) != nil }))
            .onDeleteCommand { perform(.deleteLayer) }
            .accessibilityIdentifier("halo.layer.list")
        }
    }

    /// The refusal to show under `layer`'s row: one whose control is that row.
    private func refusal(for layer: HaloLayer) -> HaloRefusal? {
        guard let refusal = model.refusal, refusal.control == "halo.layer.row.\(layer.id)" else { return nil }
        return refusal
    }

    /// Every row's height, plus room for one refusal caption.
    private func height(rows: Int, refused: Bool) -> CGFloat {
        (SuiteSize.studioRow + SuiteSpacing.xs) * CGFloat(rows) + (refused ? SuiteSize.studioRow : 0)
    }

    /// Sends the dragged row's move; the target index comes from the Model.
    private func move(_ source: IndexSet, to offset: Int, in layers: [HaloLayer]) {
        guard let from = source.first, layers.indices.contains(from),
              let target = HaloProject.moveTarget(from: from, toOffset: offset, count: layers.count)
        else { return }
        perform(.moveLayer(layers[from].id, to: target))
    }
}

/// One layer row: the select button around SidebarRow (rename on the name),
/// then its refusal caption, if any.
private struct HaloLayerRow: View {
    let layer: HaloLayer
    let selected: Bool
    let refusal: HaloRefusal?
    let perform: @MainActor (HaloCommand) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { perform(.selectLayer(layer.id)) } label: {
                SidebarRow(
                    SidebarItem(id: layer.id, title: layer.name, systemImage: layer.kind.systemImage),
                    onRename: { name in perform(.renameLayer(layer.id, name)) })
                .labelStyle(HaloLayerLabelStyle(selected: selected))
                .padding(.horizontal, SuiteSpacing.m)
                .frame(maxWidth: .infinity, minHeight: SuiteSize.studioRow, alignment: .leading)
                .background(selected ? SuiteColor.selectedTint : Color.clear, in: .rect(cornerRadius: SuiteRadius.row))
                .overlay {
                    if selected {
                        RoundedRectangle(cornerRadius: SuiteRadius.row).strokeBorder(SuiteColor.accent, lineWidth: 1)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(layer.kind.layerTitle)
            .accessibilityValue(layer.kind.layerTitle)
            .accessibilityAddTraits(selected ? .isSelected : [])
            .haloControl(id: "halo.layer.row.\(layer.id)", enabled: true, help: nil)
            .tag(layer.id)
            if let refusal {
                HaloRefusalCaption(refusal: refusal)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("halo.layer.refusal")
            }
        }
        .padding(.bottom, SuiteSpacing.xs)
    }
}

/// SidebarRow's label in W0's row look: the name in primary ink, semibold when
/// selected; the kind icon in accent when selected, else secondary ink.
private struct HaloLayerLabelStyle: LabelStyle {
    let selected: Bool

    func makeBody(configuration: Configuration) -> some View {
        Label {
            configuration.title
                .font(selected ? SuiteFont.headline : SuiteFont.body)
                .foregroundStyle(SuiteColor.textPrimary)
                .lineLimit(1)
                .truncationMode(.middle)
        } icon: {
            configuration.icon
                .foregroundStyle(selected ? SuiteColor.accent : SuiteColor.secondaryText)
        }
        .labelStyle(.titleAndIcon)
    }
}
