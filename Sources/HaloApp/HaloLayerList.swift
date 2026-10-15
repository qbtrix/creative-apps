// HaloLayerList.swift: the selected composition's layers, top first, as a
// system List of SuiteUI sidebar rows, flush under the inspector's Layers
// section (which draws the title, so the list has none). Picking a row sends
// `selectLayer`; the selection itself lives in HaloProject. Each row carries
// its layer id as its tag, the way Photo's and Design's layer lists do, and is
// one accessibility container identified as the control
// `halo.layer.row.<layer id>` (HaloControls.swift), so a click on it lands on
// the row, not on the title label's rename gesture. Its tooltip and VoiceOver
// value name the kind ("Solid layer", from HaloModel). The sidebar style draws
// no separators inside the panel; the rows sit on the panel's SuiteSpacing.m
// inset like the Composition rows, and only the selected row's kind icon takes
// the accent (the rest use secondary ink, through listItemTint). layer-panel
// (#770) replaces this body with SuiteUI's LayerList; the call site stays
// `init(model:perform:)`.
import HaloModel
import SuiteUI
import SwiftUI

struct HaloLayerList: View {
    let model: HaloProject
    var perform: @MainActor (HaloCommand) -> Void = { _ in }

    var body: some View {
        List(selection: Binding(get: { model.selectedLayerID }, set: { id in if let id { perform(.selectLayer(id)) } })) {
            ForEach(model.selectedComposition?.layers ?? []) { layer in
                SidebarRow(SidebarItem(id: layer.id, title: layer.name, systemImage: layer.kind.systemImage))
                    .help(layer.kind.layerTitle)
                    .accessibilityElement(children: .contain)
                    .accessibilityValue(layer.kind.layerTitle)
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
