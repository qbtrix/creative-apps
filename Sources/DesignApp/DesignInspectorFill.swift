// DesignInspectorFill.swift (gradient-fill DG-2): the Fill section's type switch, Solid, Linear or
// Radial, over the selection's kernel fill. It reads `fillSelection` and `fillHelp` from the Model and
// sends every pick as a `GradientIntent` through `.fill`, which DesignWindow hands to `runFill`. While
// `fillHelp` says why (nothing selected, a locked layer, or gradients not built yet) the switch is off
// and that reason is its tooltip. SuiteUI's GradientEditor isn't on dev yet (needs-ui), so a gradient
// shows a plain placeholder where its stops and angle go. Values in, intents out.
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
            if type != .solid {
                // Placeholder until SuiteUI's GradientEditor lands (#3677): its stops and angle go here.
                Text("Gradient stops and angle")
                    .font(SuiteFont.caption)
                    .foregroundStyle(SuiteColor.secondaryText)
                    .accessibilityIdentifier("design.inspector.fill-gradient")
            }
        }
    }
}
