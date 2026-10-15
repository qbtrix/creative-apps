// HaloLayerList.swift: the selected composition's layers, top first, as a
// system List in the sidebar style, flush under the inspector's Layers
// section (which draws the title, so the list has none). Each row is a plain
// Button over the whole row that sends `selectLayer` on a single click: the
// List's own selection never fired from a click here, so the row doesn't
// wait on it. The List still reads its selection from HaloProject, so the
// selected row keeps the system highlight and the arrow keys still move it.
// A row carries its layer id as its tag, the way Photo's and Design's layer
// lists do, and is the control `halo.layer.row.<layer id>`
// (HaloControls.swift). Its tooltip and VoiceOver value name the kind ("Solid
// layer", from HaloModel). The sidebar style draws no separators inside the
// panel; the rows sit on the panel's SuiteSpacing.m inset like the Composition
// rows, and only the selected row's kind icon takes the accent (the rest use
// secondary ink, through listItemTint). Layers have no rename yet, so the row
// is a plain Label, not SuiteUI's SidebarRow with its double-click rename.
// layer-panel (#770) replaces this body with SuiteUI's LayerList; the call
// site stays `init(model:perform:)`.
import HaloModel
import SuiteUI
import SwiftUI

struct HaloLayerList: View {
    let model: HaloProject
    var perform: @MainActor (HaloCommand) -> Void = { _ in }

    var body: some View {
        List(selection: Binding(get: { model.selectedLayerID }, set: { id in if let id { perform(.selectLayer(id)) } })) {
            ForEach(model.selectedComposition?.layers ?? []) { layer in
                Button { perform(.selectLayer(layer.id)) } label: {
                    Label(layer.name, systemImage: layer.kind.systemImage)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(layer.kind.layerTitle)
                .accessibilityValue(layer.kind.layerTitle)
                .accessibilityAddTraits(layer.id == model.selectedLayerID ? .isSelected : [])
                .haloControl(id: "halo.layer.row.\(layer.id)", enabled: true, help: nil)
                .listItemTint(layer.id == model.selectedLayerID ? nil : SuiteColor.secondaryText)
                .listRowSeparator(.hidden)
                .listRowInsets(.horizontal, SuiteSpacing.m)
                .tag(layer.id)
            }
        }
        .listStyle(.sidebar)
        .contentMargins(.horizontal, 0, for: .scrollContent)
        .scrollContentBackground(.hidden)
    }
}
