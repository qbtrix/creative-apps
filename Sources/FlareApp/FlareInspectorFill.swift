// FlareInspectorFill.swift: the inspector's FILL and STROKE sections
// (inspector-timeline IT-5), from `model.paint`. FILL is a color row
// (`flare.inspector.fill`) whose pick or typed hex sends `.setFill`; a
// gradient fill reads "Gradient", read only, with the reason it can't be
// edited; fills that differ read Mixed. STROKE is the color row
// (`flare.inspector.stroke`, `.setStrokeColor`), the Width bar
// (`flare.inspector.strokeWidth`, in pt: it shows the dragged value while
// scrubbing and sends `.setStrokeWidth` once on release, one undo step), and
// the Cap and Join menus (`flare.inspector.cap`, `.join`, each reading its
// choice as its value). A nil field reads Mixed. A refusal (`paintError`)
// shows above the header with the others (FlareInspector). Its intents go out
// through the window's own `perform`, and each control is disabled with the
// router's reason (`reasonFor`) while it can't act. Not through the focused scene
// value: that one is nil whenever the window isn't key, and the rows would
// then look enabled and do nothing. It only reads.
import FlareCore
import FlareModel
import SuiteUI
import SwiftUI

struct FlareInspectorFill: View {
    let paint: PaintReadout
    /// Why an intent can't act now; nil while it can (`FlareWindow.inspectorHelp`).
    let reasonFor: @MainActor (FlareIntent.Inspector) -> String?
    let perform: @MainActor (FlareIntent) -> Void
    /// The width shown while the bar is dragged; nil between drags.
    @State private var draftWidth: Double?

    /// Why a gradient fill reads only (FlarePaint's refusal for it).
    static let gradientReason = "Gradients can't be edited yet."

    var body: some View {
        InspectorSection("Fill") { fill }
        InspectorSection("Stroke") { stroke }
    }

    @ViewBuilder private var fill: some View {
        if paint.fillIsGradient {
            InspectorRow("Fill") { Text("Gradient") }
                .help(Self.gradientReason)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("flare.inspector.fill")
            Text(Self.gradientReason)
                .font(SuiteFont.caption)
                .foregroundStyle(SuiteColor.secondaryText)
                .padding(.horizontal, SuiteSpacing.m)
        } else {
            color("Fill", hex: paint.fillHex, id: "flare.inspector.fill") { .setFill(hex: $0) }
        }
    }

    @ViewBuilder private var stroke: some View {
        color("Stroke", hex: paint.strokeHex, id: "flare.inspector.stroke") { .setStrokeColor(hex: $0) }
        let widthHelp = reasonFor(.setStrokeWidth(0))
        InspectorSliderRow(
            "Width", value: draftWidth ?? paint.strokeWidth ?? 0, in: 0...100, step: 0.5, unit: "pt", decimals: 1,
            mixed: draftWidth == nil && paint.strokeWidth == nil,
            onChange: { draftWidth = $0 },
            onEnd: {
                if let width = draftWidth { send(.setStrokeWidth(width)) }
                draftWidth = nil
            })
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
