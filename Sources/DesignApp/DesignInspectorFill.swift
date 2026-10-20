// DesignInspectorFill.swift: the Fill section's type switch in Design's
// inspector (gradient-fill DG-2): Solid, Linear and Radial chips under the
// color well, the selected one the primary layer's fill type. A pick sends
// `.fill(.type(...))`, which the window runs through the workspace's
// `runFill`. While the Model's `fillHelp` says why the switch can't act (no
// fillable layer, a locked one, or gradients not built yet), the chips are
// disabled with it as their tooltip and as a hint line. The stop bar, angle
// and stop color rows arrive with DG-5. Values in, intents out.
import DesignModel
import SuiteKernel
import SuiteUI
import SwiftUI

/// The Fill section's Solid / Linear / Radial switch over the selection.
struct DesignInspectorFill: View {
    let model: DesignWorkspace
    let perform: DesignPerform

    static let types: [InspectorOption<FillType>] = [
        InspectorOption(id: .solid, title: "Solid"), InspectorOption(id: .linear, title: "Linear"),
        InspectorOption(id: .radial, title: "Radial"),
    ]

    var body: some View {
        let help = model.fillHelp
        let selected = model.fillSelection.map { GradientRules.type(of: $0.fill) } ?? .solid
        VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            Text("Type").font(SuiteFont.inspectorLabel).foregroundStyle(SuiteColor.textSecondary)
            ChoiceChips(options: Self.types, selected: selected) { perform(.fill(.type($0))) }
                .disabled(help != nil)
                .help(help ?? "")
                .accessibilityElement(children: .contain)
                .accessibilityLabel("Fill type")
                .suiteControl(id: DesignControlID.inspectorFillType, enabled: help == nil, reason: help)
            if let help { InspectorNote(help) }
        }
    }
}
