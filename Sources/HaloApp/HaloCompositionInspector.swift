// HaloCompositionInspector.swift: Halo's inspector for the selected
// composition, in the Pro density pattern of docs/design.md. With a layer
// selected it hosts HaloLayerInspector (the layer's header and slots);
// otherwise it shows an InspectorHeader (name, size, rate and length) and a
// Composition section of read-only rows, their values in
// SuiteFont.inspectorValue (semibold, tabular digits); the Size row's
// tooltip says it is in pixels (HaloComposition.sizeHelp). Either way the layer list follows
// under a Layers section. All text comes from HaloModel; views only read it.
// The read-only values carry `halo.inspector.composition.*` identifiers so a
// journey reads them; they aren't controls, so they stay out of halo.controls.
// The header is `halo.inspector.header` (here and in HaloLayerInspector), one
// element reading "name, size, rate · length". The inspector as a whole is
// SuiteWindow's `suite.inspector`: an id on this root merged into that
// element and was overwritten, so a journey never found `halo.inspector`.
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
                    .accessibilityIdentifier("halo.inspector.header")
                InspectorSection("Composition") {
                    InspectorRow("Size") {
                        Text(comp.sizeText).font(SuiteFont.inspectorValue)
                            .accessibilityIdentifier("halo.inspector.composition.size")
                    }
                    .help(HaloComposition.sizeHelp)
                    InspectorRow("Frame Rate") {
                        Text(comp.frameRateText).font(SuiteFont.inspectorValue)
                            .accessibilityIdentifier("halo.inspector.composition.frameRate")
                    }
                    InspectorRow("Duration") {
                        Text(comp.durationText).font(SuiteFont.inspectorValue)
                            .accessibilityIdentifier("halo.inspector.composition.duration")
                    }
                }
            }
            InspectorSection("Layers") {
                HaloLayerList(model: model, perform: perform)
            }
        }
    }
}
