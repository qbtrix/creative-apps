// HaloFillInspector.swift (gradient-fill HG-2): the FILL slot of Halo's layer
// inspector, shown only while a solid or shape layer is selected (`shows`;
// text keeps its colour row in TEXT, a null has no fill). It opens with the
// Solid / Linear / Radial switch (`halo.inspector.fillType`, a chip each,
// `halo.inspector.fillType.<type>`) over the selection's kernel fill
// (`fillSelection`); a pick sends `.type(_)` to `runFill`. Under it a solid
// fill is the layer's colour row (`halo.inspector.fill.color`, from
// `selectedLayerColor`, sending .setLayerColor in 8-bit sRGB), and a gradient
// is SuiteUI's GradientEditor without its own switch (the chips are it),
// whose gestures each send one GradientIntent to `runFill`, which the window
// hands to `HaloProject.runFill`. While `fillHelp` says why (gradients not
// built yet, no layer) the switch and the editor are off with that reason as
// their tooltip and as a note under the switch (`halo.inspector.fillHelp`).
// Its inputs are values, so a snapshot can show any fill; `init(model:)`
// reads them from the project. Values in, intents out.
import HaloModel
import SuiteKernel
import SuiteUI
import SwiftUI

struct HaloFillInspector: View {
    /// The selected layer's fill in its box; nil reads Solid.
    let selection: FillSelection?
    /// Why the fill commands can't run; nil while they can.
    let help: String?
    /// The layer's colour, the solid fill's row; nil hides the row.
    let color: HaloLayerColor?
    /// Why the colour row can't act; nil while it can.
    let colorHelp: String?
    var perform: @MainActor (HaloCommand) -> Void = { _ in }
    var runFill: @MainActor (GradientIntent) -> Void = { _ in }

    nonisolated static let typeID = "halo.inspector.fillType"
    nonisolated static let helpID = "halo.inspector.fillHelp"
    nonisolated static let colorID = "halo.inspector.fill.color"

    /// The switch's chips, one control each (`halo.inspector.fillType.<type>`).
    nonisolated static let options = FillType.allCases.map {
        InspectorOption(id: $0, title: $0.rawValue.capitalized, identifier: "\(typeID).\($0.rawValue)")
    }

    /// Whether FILL shows for a layer of `kind`: solids and shapes only.
    nonisolated static func shows(_ kind: HaloLayerKind?) -> Bool { kind == .solid || kind == .shape }

    /// The fill type the switch shows.
    var type: FillType { selection.map { GradientRules.type(of: $0.fill) } ?? .solid }

    var body: some View {
        InspectorSection("Fill") {
            ChoiceChips(options: Self.options, selected: type) { runFill(.type($0)) }
                .disabled(help != nil)
                .help(help ?? "Fill type")
                .haloControl(id: Self.typeID, enabled: help == nil, help: help, identifies: false)
            if let help { InspectorNote(help, kind: .secondary, identifier: Self.helpID) }
            if let selection, type != .solid {
                GradientEditor(fill: selection.fill, box: selection.box, types: [type]) { runFill($0) }
                    .disabled(help != nil)
                    .help(help ?? "Gradient stops and angle")
            } else if let color {
                InspectorColorWellRow("Color", color: color.hex) { perform(.setLayerColor(HaloLayerColor(hex: $0))) }
                    .disabled(colorHelp != nil)
                    .help(colorHelp ?? "Color")
                    .haloControl(id: Self.colorID, enabled: colorHelp == nil, help: colorHelp)
            }
        }
    }
}

extension HaloFillInspector {
    /// FILL for the project's selected layer.
    init(
        model: HaloProject, perform: @escaping @MainActor (HaloCommand) -> Void,
        runFill: @escaping @MainActor (GradientIntent) -> Void
    ) {
        let color = model.selectedLayerColor
        self.init(
            selection: model.fillSelection, help: model.fillHelp, color: color,
            colorHelp: color.flatMap { model.unavailableHelp(for: .setLayerColor($0)) }, perform: perform,
            runFill: runFill)
    }
}
