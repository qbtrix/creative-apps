// HaloCompositionInspector.swift: the selected composition in Halo's
// inspector, in the Pro density pattern of docs/design.md: an InspectorHeader
// (name, size, rate and length), a Composition section of read-only rows
// (HaloProject has no method to change them yet), then the layer list under
// a Layers section. All text comes from HaloModel; views only read it.
import HaloModel
import SuiteUI
import SwiftUI

struct HaloCompositionInspector: View {
    let comp: HaloComposition
    let selectedLayerID: HaloLayer.ID?
    var onSelectLayer: @MainActor (HaloLayer.ID) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            InspectorHeader(comp.name, details: comp.headerDetails)
            InspectorSection("Composition") {
                InspectorRow("Size") { Text(comp.sizeText).monospacedDigit() }
                InspectorRow("Frame Rate") { Text(comp.frameRateText).monospacedDigit() }
                InspectorRow("Duration") { Text(comp.durationText).monospacedDigit() }
            }
            InspectorSection("Layers") {
                HaloLayerList(layers: comp.layers, selection: selectedLayerID, onSelect: onSelectLayer)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("halo.inspector")
    }
}
