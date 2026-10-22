// FlareInspectorFill.swift: the inspector's FILL and STROKE sections
// (inspector-timeline IT-5, gradient-fill FG-2), from `model.paint`. FILL
// opens with the Solid / Linear / Radial switch (`flare.inspector.fillType`)
// over every fill; a pick sends `.runFill(.type(_))`. Under it a solid fill is
// a color row (`flare.inspector.fill`) whose pick or typed hex sends
// `.setFill`, a gradient (`paint.gradient`) is SuiteUI's GradientEditor
// without its own type switch (`editorTypes`), whose gestures send
// `.runFill(_)`, and fills that differ read Mixed. The switch
// and the editor are off, with the router's reason as their tooltip and as a
// note under the switch (`flare.inspector.fillHelp`), while the kernel's
// `fillHelp` says why. STROKE is the color row
// (`flare.inspector.stroke`, `.setStrokeColor`), the Width bar
// (`flare.inspector.strokeWidth`, in pt: each drag sample sends
// `.scrubStrokeWidth`, so the canvas shows the width live, and the release
// sends `.endScrub`, so the whole drag is one undo step), and
// the Cap and Join menus (`flare.inspector.cap`, `.join`, each reading its
// choice as its value). A nil field reads Mixed. A refusal (`paintError`)
// shows above the header with the others (FlareInspector). Its intents go out
// through the window's own `perform`, and each control is disabled with the
// router's reason (`reasonFor`) while it can't act. Not through the focused scene
// value: that one is nil whenever the window isn't key, and the rows would
// then look enabled and do nothing. It only reads.
import FlareCore
import FlareModel
import SuiteKernel
import SuiteUI
import SwiftUI

struct FlareInspectorFill: View {
    let paint: PaintReadout
    /// Why an intent can't act now; nil while it can (`FlareWindow.inspectorHelp`).
    let reasonFor: @MainActor (FlareIntent.Inspector) -> String?
    let perform: @MainActor (FlareIntent) -> Void

    /// The fill type switch's chips, one control each (`flare.inspector.fillType.<type>`).
    static let fillTypes = FillType.allCases.map {
        InspectorOption(id: $0, title: $0.rawValue.capitalized, identifier: "flare.inspector.fillType.\($0.rawValue)")
    }

    /// The note under the switch that says why it is off.
    static let fillHelpID = "flare.inspector.fillHelp"

    /// The editor's own switch offers only `fill`'s type, so it hides: FILL's switch above is the one Type control.
    nonisolated static func editorTypes(_ fill: Fill) -> [FillType] { [GradientRules.type(of: fill)] }

    var body: some View {
        InspectorSection("Fill") { fill }
        InspectorSection("Stroke") { stroke }
    }

    @ViewBuilder private var fill: some View {
        let help = reasonFor(.runFill(.type(.solid)))
        let type = paint.gradient.map { GradientRules.type(of: $0.fill) } ?? (paint.fillIsGradient ? nil : .solid)
        ChoiceChips(options: Self.fillTypes, selected: type) { send(.runFill(.type($0))) }
            .disabled(help != nil)
            .help(help ?? "Fill type")
            .suiteControl(id: "flare.inspector.fillType", enabled: help == nil, reason: help, identifies: false)
        if let help { InspectorNote(help, kind: .secondary, identifier: Self.fillHelpID) }
        if let gradient = paint.gradient {
            GradientEditor(fill: gradient.fill, box: gradient.box, types: Self.editorTypes(gradient.fill)) {
                send(.runFill($0))
            }
                .disabled(help != nil)
                .help(help ?? "Edit Fill")
        } else {
            color("Fill", hex: paint.fillHex, id: "flare.inspector.fill") { .setFill(hex: $0) }
        }
    }

    @ViewBuilder private var stroke: some View {
        color("Stroke", hex: paint.strokeHex, id: "flare.inspector.stroke") { .setStrokeColor(hex: $0) }
        let widthHelp = reasonFor(.setStrokeWidth(0))
        InspectorSliderRow(
            "Width", value: paint.strokeWidth ?? 0, in: 0...100, step: 0.5, unit: "pt", decimals: 1,
            mixed: paint.strokeWidth == nil,
            onChange: { send(.scrubStrokeWidth($0)) },
            onEnd: { send(.endScrub) })
            .accessibilityIdentifier("flare.inspector.strokeWidth")
            .disabled(widthHelp != nil)
            .help(widthHelp ?? "Stroke Width")
        picker("Cap", id: "flare.inspector.cap", selection: paint.cap?.rawValue,
               choices: Stroke.Cap.allCases.map(\.rawValue)) { .setStrokeCap($0) }
        picker("Join", id: "flare.inspector.join", selection: paint.join?.rawValue,
               choices: Stroke.Join.allCases.map(\.rawValue)) { .setStrokeJoin($0) }
    }

    /// A color row for `hex` ("RRGGBB"), or a Mixed row when it is nil.
    @ViewBuilder private func color(
        _ label: String, hex: String?, id: String, intent: @escaping (String) -> FlareIntent.Inspector
    ) -> some View {
        if let hex, let shown = HexColor(hex) {
            let reason = reasonFor(intent(hex))
            InspectorColorWellRow(label, color: shown) { send(intent(String($0.text.dropFirst()))) }
                .disabled(reason != nil)
                .help(reason ?? label)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier(id)
        } else {
            InspectorRow(label) { Text("Mixed") }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier(id)
        }
    }

    /// A Cap or Join menu; Mixed (a choice that sends nothing) when `selection` is nil.
    private func picker(
        _ label: String, id: String, selection: String?, choices: [String],
        intent: @escaping (String) -> FlareIntent.Inspector
    ) -> some View {
        let mixed = "mixed", current = selection ?? mixed
        let options = (selection == nil ? [mixed] : []) + choices
        let reason = reasonFor(intent(current == mixed ? choices.first ?? "" : current))
        return InspectorPickerRow(
            label, options: options.map { InspectorOption(id: $0, title: $0.capitalized) }, selection: current
        ) { picked in if picked != mixed { send(intent(picked)) } }
            .disabled(reason != nil)
            .help(reason ?? label)
            .accessibilityValue(Text(verbatim: current.capitalized))
            .accessibilityIdentifier(id)
    }

    private func send(_ intent: FlareIntent.Inspector) { perform(.inspector(intent)) }
}
