// DesignInspectorFill.swift (gradient-fill DG-2): the Fill section's type switch, Solid, Linear or
// Radial, over the selection's kernel fill. It reads `fillSelection` and `fillHelp` from the Model and
// sends every pick as a `GradientIntent` through `.fill`, which DesignWindow hands to `runFill`. While
// `fillHelp` says why (nothing selected, a locked layer, or gradients not built yet) the switch is off
// and that reason is its tooltip and a note under it. The switch is SuiteUI's: a gradient shows its
// GradientEditor (the switch, its stops, colour and angle; GF-3 landed it, gradient-fill DG-u), a solid
// its `GradientTypeSwitch` alone, both under `design.inspector.fill-type`. Values in, intents out.
import DesignModel
import SuiteKernel
import SuiteUI
import SwiftUI

struct DesignInspectorFill: View {
    let model: DesignWorkspace
    let perform: DesignPerform

    var body: some View {
        let help = model.fillHelp
        let type = model.fillSelection.map { GradientRules.type(of: $0.fill) } ?? .solid
        VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            if let selection = model.fillSelection, type != .solid {
                // SuiteUI's editor with its switch: the stop bar, the stop's colour and location and, for a
                // linear fill, the angle, each gesture an intent to `runFill`.
                GradientEditor(fill: selection.fill, box: selection.box, typeID: DesignControlID.inspectorFillType,
                               typeHelp: help) { perform(.fill($0)) }
                    .disabled(help != nil)
                    .help(help ?? "Gradient stops and angle")
            } else {
                GradientTypeSwitch(type: type, typeID: DesignControlID.inspectorFillType, help: help) {
                    perform(.fill(.type($0)))
                }
            }
        }
    }
}
