// HaloLayerList.swift: the selected composition's layers, top first, flush
// under the inspector's Layers section (which draws the title, so the list has
// none). The rows are a plain stack, not a List: a sidebar List added its own
// selection inset and leading padding, so the rows sat about 10 pt inside the
// column. Here each row spans the section's full width, the same leading and
// trailing edges as the Composition rows (InspectorSection's SuiteSpacing.m
// panel inset), with its icon and name SuiteSpacing.m inside, like an
// InspectorRow's label. Each row is a plain Button over the whole row that
// sends `selectLayer` on a single click; Tab moves between rows. The selected
// row draws the design.md Selected state: the `stateSelected` tint
// (SuiteColor.selectedTint) with a 1 pt accent outline at SuiteRadius.row and
// a semibold name, the same blue family as the timeline's selected track,
// instead of the system's grey highlight. Names are in primary ink, never
// inactive grey; only the selected row's kind icon takes the accent, the rest
// use secondary ink. A row is the control `halo.layer.row.<layer id>`
// (HaloControls.swift) and carries its layer id as its tag. Its tooltip and
// VoiceOver value name the kind ("Solid layer", from HaloModel). A composition
// with no layers shows the timeline's one-line hint in secondary text. Layers
// have no rename yet, so the row is a plain Label, not SuiteUI's SidebarRow.
// layer-panel (#770) replaces this body with SuiteUI's LayerList; the call
// site stays `init(model:perform:)`.
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
            ForEach(layers) { layer in
                let selected = layer.id == model.selectedLayerID
                Button { perform(.selectLayer(layer.id)) } label: {
                    Label {
                        Text(layer.name)
                            .font(selected ? SuiteFont.headline : SuiteFont.body)
                            .foregroundStyle(SuiteColor.textPrimary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    } icon: {
                        Image(systemName: layer.kind.systemImage)
                            .foregroundStyle(selected ? SuiteColor.accent : SuiteColor.secondaryText)
                    }
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
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
