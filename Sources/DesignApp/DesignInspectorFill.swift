// DesignInspectorFill.swift (gradient-fill DG-2): the Fill section's type switch, Solid, Linear or
// Radial, over the selection's kernel fill. It reads `fillSelection` and `fillHelp` from the Model and
// sends every pick as a `GradientIntent` through `.fill`, which DesignWindow hands to `runFill`. While
// `fillHelp` says why (nothing selected, a locked layer, or gradients not built yet) the switch is off
// and that reason is its tooltip. A gradient shows SuiteUI's GradientEditor under the switch (its stops,
// colour and angle; GF-3 landed it, gradient-fill DG-u). Values in, intents out.
import DesignModel
import SuiteKernel
import SuiteUI
import SwiftUI

struct DesignInspectorFill: View {
    let model: DesignWorkspace
    let perform: DesignPerform

    nonisolated static let options = FillType.allCases.map {
        InspectorOption(
            id: $0, title: $0.rawValue.capitalized, identifier: "\(DesignControlID.inspectorFillType).\($0.rawValue)")
    }

    var body: some View {
        let help = model.fillHelp
        let type = model.fillSelection.map { GradientRules.type(of: $0.fill) } ?? .solid
        VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            ChoiceChips(options: Self.options, selected: type) { perform(.fill(.type($0))) }
                .disabled(help != nil)
                .help(help ?? "Fill type")
                .suiteControl(id: DesignControlID.inspectorFillType, enabled: help == nil, reason: help, identifies: false)
            if let selection = model.fillSelection, type != .solid {
                // SuiteUI's editor without its own switch (the chips above are it): the stop bar, the stop's
                // colour and, for a linear fill, the angle, each gesture an intent to `runFill`.
                GradientEditor(fill: selection.fill, box: selection.box, types: [type]) { perform(.fill($0)) }
                    .disabled(help != nil)
                    .help(help ?? "Gradient stops and angle")
            }
        }
    }
}
