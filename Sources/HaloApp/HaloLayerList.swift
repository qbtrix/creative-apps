// HaloLayerList.swift: the selected composition's layers, top first, as a
// system List of SuiteUI sidebar rows in the inspector. Picking a row calls
// `onSelect`; the selection itself lives in HaloProject.
import HaloModel
import SuiteUI
import SwiftUI

struct HaloLayerList: View {
    let layers: [HaloLayer]
    let selection: HaloLayer.ID?
    var onSelect: @MainActor (HaloLayer.ID) -> Void = { _ in }

    var body: some View {
        List(selection: Binding(get: { selection }, set: { id in if let id { onSelect(id) } })) {
            Section("Layers") {
                ForEach(layers) { layer in
                    SidebarRow(SidebarItem(id: layer.id, title: layer.name, systemImage: layer.kind.systemImage))
                }
            }
        }
    }
}
