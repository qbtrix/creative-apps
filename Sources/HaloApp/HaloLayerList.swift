// HaloLayerList.swift: the selected composition's layers, top first, as a
// system List of SuiteUI sidebar rows, flush under the inspector's Layers
// section (which draws the title, so the list has none). Picking a row sends
// `selectLayer`; the selection itself lives in HaloProject. Each row is the
// control `halo.layer.row.<layer id>` (HaloControls.swift). layer-panel
// (#770) replaces this body; the call site stays `init(model:perform:)`.
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
                    .haloControl(id: "halo.layer.row.\(layer.id)", enabled: true, help: nil)
            }
        }
        .scrollContentBackground(.hidden)
    }
}
