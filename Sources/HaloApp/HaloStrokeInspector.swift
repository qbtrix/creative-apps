// HaloStrokeInspector.swift (stroke-style HK-2): the STROKE slot of Halo's
// layer inspector, under FILL, shown only while a shape layer is selected
// (`shows`; text, solids and nulls take no stroke). It is SuiteUI's
// StrokeEditor on the selection's kernel stroke (`selectedStroke`), with the
// trim rows (Halo trims paths), each gesture one StrokeIntent sent to
// `runStroke`, which the window hands to `HaloProject.runStroke`. While
// `strokeHelp` says why (the HK-1 stubs until HK-6) every row is off with
// that reason as its tooltip and as the editor's note. Dash and trim draw
// once HK-5 renders them, so no dash help is passed. Its inputs are values,
// so a snapshot can show any stroke; `init(model:)` reads them from the
// project. Values in, intents out.
import HaloModel
import SuiteKernel
import SuiteUI
import SwiftUI

struct HaloStrokeInspector: View {
    /// The selected shape layer's stroke; nil shows Add Stroke alone.
    let stroke: VectorStroke?
    /// Why the stroke commands can't run; nil while they can.
    let help: String?
    var runStroke: @MainActor (StrokeIntent) -> Void = { _ in }

    /// Whether STROKE shows for a layer of `kind`: shape layers only.
    nonisolated static func shows(_ kind: HaloLayerKind?) -> Bool { kind == .shape }

    var body: some View {
        InspectorSection("Stroke") {
            StrokeEditor(stroke: stroke, help: help, dashHelp: nil) { runStroke($0) }
        }
    }
}

extension HaloStrokeInspector {
    /// STROKE for the project's selected layer.
    init(model: HaloProject, runStroke: @escaping @MainActor (StrokeIntent) -> Void) {
        self.init(stroke: model.selectedStroke, help: model.strokeHelp, runStroke: runStroke)
    }
}
