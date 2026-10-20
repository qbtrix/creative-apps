// DesignInspectorStyle.swift: the style rows of Design's inspector (style-rows
// SR-a). Opacity (a bar in the Layer section), Corners (the Radius bar, off
// with its reason on a kind with no corners), and Stroke (Add Stroke on a layer
// with none; else its Color well, its Width bar and Remove Stroke), plus the
// X, Y, W and H fields the Frame section shows. A scrub never writes the
// workspace per value: each value previews on the window's live box
// (DesignLiveDrag), which only these rows and the canvas read, and the end of
// the drag, key or typed value lands the last one as one step (`.endEditRun`).
// Hosted without a box, each value goes straight to `.setStyle`. The hint
// says why the rows are off ("Unlock A to change it.", #276) and starts at the
// value column: the X field's leading edge, measured in
// DesignNodeProperties.hintSpace (SuiteUI's InspectorNote draws it).
// Every control's help comes from the Model. Values in, intents out.
import DesignModel
import SuiteKernel
import SuiteUI
import SwiftUI

/// Sends a scrubbed row's values: each previews on the live box, and `end` lands the last as one step.
@MainActor struct DesignStyleSend {
    let model: DesignWorkspace
    let live: DesignLiveDrag?
    let perform: DesignPerform

    /// One value of a scrub, shown on the live box's copy; straight to the workspace without a box.
    func preview(_ change: DesignStyleChange) {
        guard let live else { return perform(.setStyle(change)) }
        if !live.isLive { live.begin(from: model) }
        live.preview(change)
    }

    /// Ends the scrub: the last previewed value lands as one undo step.
    func end() { perform(.endEditRun) }

    /// One whole edit (a click, a typed value): set it, then end its run.
    func commit(_ change: DesignStyleChange) {
        perform(.setStyle(change))
        perform(.endEditRun)
    }
}

/// One of X, Y, W and H over the selection. A drag previews and lands once at mouse-up; a typed
/// value, an arrow key or an accessibility adjust is one step of its own. Disabled with `help`.
struct DesignFrameScrub: View {
    let model: DesignWorkspace
    let name: String
    let field: DesignFrameField
    let range: ClosedRange<Double>
    let read: (DesignNode) -> Double
    let help: String?
    let perform: DesignPerform
    @Environment(\.designLiveDrag) private var live
    @State private var dragging = false

    var body: some View {
        let send = DesignStyleSend(model: model, live: live, perform: perform)
        let value = live?.workspace?.sharedValue(read) ?? model.sharedValue(read) ?? 0
        ScrubField(name, value: value, in: range, step: 1, unit: "pt", decimals: 1) { new in
            dragging ? send.preview(.frame(field, new)) : send.commit(.frame(field, new))
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in dragging = true }
                .onEnded { _ in
                    dragging = false
                    send.end()
                })
        .disabled(help != nil)
        .help(help ?? "")
        .suiteControl(id: DesignControlID.frameField(field), enabled: help == nil, reason: help)
    }
}

/// The Layer section's Opacity bar, in percent: "Mixed" when the selected layers differ.
struct DesignOpacityRow: View {
    let model: DesignWorkspace
    let perform: DesignPerform
    @Environment(\.designLiveDrag) private var live

    var body: some View {
        let send = DesignStyleSend(model: model, live: live, perform: perform)
        let opacity = (live?.workspace ?? model).sharedValue(\.opacity)
        let help = model.styleHelp(.opacity)
        InspectorSliderRow(
            "Opacity", value: (opacity ?? 1) * 100, in: 0...100, step: 1, unit: "%", decimals: 0, mixed: opacity == nil,
            onChange: { send.preview(.opacity($0 / 100)) }, onEnd: send.end
        )
        .disabled(help != nil)
        .help(help ?? "")
        .suiteControl(id: DesignControlID.inspectorOpacity, enabled: help == nil, reason: help)
    }
}

/// The Corners and Stroke sections over the selection.
struct DesignInspectorStyle: View {
    let model: DesignWorkspace
    let perform: DesignPerform
    @Environment(\.designLiveDrag) private var live

    var body: some View {
        let send = DesignStyleSend(model: model, live: live, perform: perform)
        let shown = live?.workspace ?? model
        let radiusHelp = model.styleHelp(.cornerRadius)
        let radius = shown.sharedValue(\.cornerRadius)
        let most = model.selectedNodes.map(\.maxCornerRadius).max() ?? 0
        InspectorSection("Corners") {
            InspectorSliderRow(
                "Radius", value: radius ?? 0, in: 0...Swift.max(1, most), step: 1, unit: "pt", decimals: 0,
                mixed: radius == nil, onChange: { send.preview(.cornerRadius($0)) }, onEnd: send.end
            )
            .disabled(radiusHelp != nil)
            .help(radiusHelp ?? "")
            .suiteControl(id: DesignControlID.inspectorCornerRadius, enabled: radiusHelp == nil, reason: radiusHelp)
        }
        InspectorSection("Stroke") {
            strokeRows(shown, send: send, help: model.styleHelp(.stroke))
        }
    }

    /// Add Stroke while no selected layer has one; else Color, Width, Join, Cap, Dash and Remove Stroke, all
    /// read through the kernel stroke (`vectorStroke`, `selectedStroke`), never DesignStroke's fields. No trim:
    /// Design leaves it to the animation apps (`trimHelp`). A placeholder until SuiteUI's StrokeEditor lands.
    @ViewBuilder
    private func strokeRows(_ shown: DesignWorkspace, send: DesignStyleSend, help: String?) -> some View {
        if let first = shown.selectedNodes.lazy.compactMap(\.vectorStroke).first {
            // nil when the layers differ (a layer with no stroke differs from one with a stroke).
            let color: FillColor? = shown.sharedValue { $0.vectorStroke?.color } ?? nil
            let width: Double? = shown.sharedValue { $0.vectorStroke?.width } ?? nil
            let keep = DesignColor(color ?? first.color)
            if let color {
                let well = DesignColor(color)
                InspectorColorWellRow("Color", color: HexColor(well.red, well.green, well.blue)) {
                    perform(.setStyle(.stroke(DesignStroke(color: DesignColor($0.red, $0.green, $0.blue), width: width ?? first.width))))
                }
                .disabled(help != nil)
                .help(help ?? "")
                .suiteControl(id: DesignControlID.inspectorStrokeColor, enabled: help == nil, reason: help, identifies: false)
            } else {
                InspectorRow("Color") {
                    Text("Mixed").font(SuiteFont.inspectorValue).foregroundStyle(SuiteColor.secondaryText)
                }
            }
            InspectorSliderRow(
                "Width", value: width ?? first.width, in: StrokeRules.widths, step: 1, unit: "pt", decimals: 1,
                mixed: width == nil, onChange: { send.preview(.stroke(DesignStroke(color: keep, width: $0))) }, onEnd: send.end
            )
            .disabled(help != nil)
            .help(help ?? "")
            .suiteControl(id: DesignControlID.inspectorStrokeWidth, enabled: help == nil, reason: help)
            let join: StrokeJoin? = shown.sharedValue { $0.vectorStroke?.join } ?? nil
            let cap: StrokeCap? = shown.sharedValue { $0.vectorStroke?.cap } ?? nil
            stylePicker("Join", id: DesignControlID.inspectorStrokeJoin, selection: join?.rawValue,
                        choices: StrokeJoin.allCases.map(\.rawValue), help: shown.strokeStyleHelp)
            stylePicker("Cap", id: DesignControlID.inspectorStrokeCap, selection: cap?.rawValue,
                        choices: StrokeCap.allCases.map(\.rawValue), help: shown.strokeStyleHelp)
            stylePicker("Dash", id: DesignControlID.inspectorStrokeDash, selection: StrokeRules.preset(of: first).rawValue,
                        choices: DashPreset.allCases.map(\.rawValue), help: shown.strokeDashHelp)
            InspectorAction(ToolbarAction(
                "Remove Stroke", systemImage: "minus", unavailableHelp: help, identifier: DesignControlID.inspectorStrokeRemove
            ) { send.commit(.stroke(nil)) })
        } else {
            InspectorAction(ToolbarAction(
                "Add Stroke", systemImage: "plus", unavailableHelp: help, identifier: DesignControlID.inspectorStrokeAdd
            ) { send.commit(.stroke(.default)) })
        }
    }

    /// A Join, Cap or Dash menu over `choices`; Mixed when `selection` is nil. Disabled with `help`, which
    /// stays set until DK-6 builds `setStroke` (Dash until the core bump); a pick then goes to `setStroke`.
    private func stylePicker(
        _ label: String, id: String, selection: String?, choices: [String], help: String?
    ) -> some View {
        let mixed = "mixed", current = selection ?? mixed
        let options = (selection == nil ? [mixed] : []) + choices
        return InspectorPickerRow(
            label, options: options.map { InspectorOption(id: $0, title: $0.capitalized) }, selection: current
        ) { _ in }
            .disabled(help != nil)
            .help(help ?? label)
            .accessibilityValue(Text(verbatim: current.capitalized))
            .suiteControl(id: id, enabled: help == nil, reason: help)
    }
}

