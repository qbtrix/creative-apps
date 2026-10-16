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
// SuiteWindow doesn't scroll its inspector, so this one scrolls itself: a
// selected layer's TRANSFORM rows stack under their bars at the inspector's
// width, and unscrolled they stood taller than a 640 pt window, which pushed
// the sidebar's rows above the window and the status bar, timeline and layer
// rows below it. Snapshots draw it unscrolled (ImageRenderer can't draw a
// ScrollView), as HaloTimelineView does. Its indicators are `.never`, as in
// Photo's inspector tabs: with legacy scrollers the vertical one was an
// unlabelled button to the app audit's Unnamed check. The column still
// scrolls by wheel and trackpad.
import HaloModel
import SuiteUI
import SwiftUI

struct HaloCompositionInspector: View {
    let model: HaloProject
    var perform: @MainActor (HaloCommand) -> Void = { _ in }
    @Environment(\.suiteSnapshotRendering) private var snapshot

    var body: some View {
        if snapshot {
            content
        } else {
            ScrollView(.vertical) { content }
                .scrollIndicators(.never)
        }
    }

    private var content: some View {
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
