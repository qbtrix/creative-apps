// HaloCompositionInspector.swift: Halo's inspector for the selected
// composition, in the Pro density pattern of docs/design.md. With a layer
// selected it hosts HaloLayerInspector (the layer's header and slots);
// otherwise it shows an InspectorHeader (name, size, rate and length) and a
// Composition section of read-only rows. Either way the layer list follows
// under a Layers section. All text comes from HaloModel; views only read it.
import HaloModel
import SuiteUI
import SwiftUI

struct HaloCompositionInspector: View {
    let model: HaloProject
    var perform: @MainActor (HaloCommand) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.selectedLayerHeader != nil {
                HaloLayerInspector(model: model, perform: perform)
            } else if let comp = model.selectedComposition {
                InspectorHeader(comp.name, details: comp.headerDetails)
                InspectorSection("Composition") {
                    InspectorRow("Size") { Text(comp.sizeText).monospacedDigit() }
                    InspectorRow("Frame Rate") { Text(comp.frameRateText).monospacedDigit() }
                    InspectorRow("Duration") { Text(comp.durationText).monospacedDigit() }
                }
            }
            InspectorSection("Layers") {
                HaloLayerList(model: model, perform: perform)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("halo.inspector")
    }
}
