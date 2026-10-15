// HaloLayerList.swift: the selected composition's layers, top first, flush
// under the inspector's Layers section (which draws the title, so the list has
// none), as an editable list (layer-panel, #770). The rows are a plain stack,
// not a List: a macOS List insets its rows horizontally even with zero row
// insets, hidden separators and clear row backgrounds, so the selected row
// stopped spanning the column and the icons moved in (HaloLayerListTests).
// Each row spans the section's full width, the same edges as the Composition
// rows, with its icon and name SuiteSpacing.m inside, and SuiteSpacing.xs
// between rows; the stack sizes itself, so it never scrolls inside the
// inspector's scroll view. Each row is SuiteUI's SidebarRow with no Button
// around it: a macOS Button tracks the mouse itself, so SidebarRow's
// double-click never fired, and it folds its label into one accessibility
// element, hiding the name and the rename field. A click anywhere on the row
// sends `selectLayer` through a simultaneous tap, so SidebarRow's double-click
// on the name still renames it on the row (SidebarRow trims the name and drops
// an empty one, then the row sends `renameLayer(id, name)`); a double-click
// also selects. The row is one accessibility element that contains the name
// and the rename field, named by the layer, with the button trait and a
// default action that selects. Rows are not Tab stops; the stack is.
// Each row drags its layer id, and a layer
// id dropped on row i sends `moveLayer(id, to: i)`, so dropping on the bottom
// row puts the layer at the bottom; the view does no offset math. The stack
// takes focus on a click, like the timeline, so Delete (⌫) there sends
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
        VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            if layers.isEmpty {
                Label("No layers yet. Add one from Layer > New.", systemImage: "square.stack.3d.up")
                    .font(SuiteFont.caption)
                    .foregroundStyle(SuiteColor.secondaryText)
                    .accessibilityIdentifier("halo.layer.empty")
            }
            ForEach(Array(layers.enumerated()), id: \.element.id) { index, layer in
                HaloLayerRow(
                    layer: layer, selected: layer.id == model.selectedLayerID,
                    refusal: refusal(for: layer), perform: perform)
                .dropDestination(for: String.self) { ids, _ in
                    drop(ids, at: index, in: layers)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .focusable()
        .focusEffectDisabled()
        .onDeleteCommand { perform(.deleteLayer) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("halo.layer.list")
    }

    /// The refusal to show under `layer`'s row: one whose control is that row.
    private func refusal(for layer: HaloLayer) -> HaloRefusal? {
        guard let refusal = model.refusal, refusal.control == "halo.layer.row.\(layer.id)" else { return nil }
        return refusal
    }

    /// Moves a layer id dropped on the row at `index` to that index. Ids that
    /// aren't this composition's layers, or a row dropped on itself, do nothing.
    private func drop(_ ids: [String], at index: Int, in layers: [HaloLayer]) -> Bool {
        guard let id = ids.first, let from = layers.firstIndex(where: { $0.id == id }) else { return false }
        if from != index { perform(.moveLayer(id, to: index)) }
        return true
    }
}

/// One layer row: SidebarRow selected by a click (rename on the name),
/// dragging its layer id, then its refusal caption, if any.
private struct HaloLayerRow: View {
    let layer: HaloLayer
    let selected: Bool
    let refusal: HaloRefusal?
    let perform: @MainActor (HaloCommand) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
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
            .simultaneousGesture(TapGesture().onEnded { perform(.selectLayer(layer.id)) })
            .draggable(layer.id)
            .help(layer.kind.layerTitle)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(layer.name)
            .accessibilityValue(layer.kind.layerTitle)
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
            .accessibilityAction { perform(.selectLayer(layer.id)) }
            .haloControl(id: "halo.layer.row.\(layer.id)", enabled: true, help: nil)
            .tag(layer.id)
            if let refusal {
                HaloRefusalCaption(refusal: refusal)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("halo.layer.refusal")
            }
        }
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
