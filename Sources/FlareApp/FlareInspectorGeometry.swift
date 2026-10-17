// FlareInspectorGeometry.swift: the inspector's TRANSFORM section
// (IT-4; not named Transform: it is a view, not SuiteModel's transform
// concept). Per `model.animatedProperties` row, an InspectorSliderRow
// (`flare.inspector.<property>`, "Mixed" when the layers differ, stepping by
// its last shown place; opacity shown in %) and a KeyframeButton
// (`flare.inspector.<property>.key`). A scrub sends `.scrub` with its start
// value, then `.endScrub`: one undo step. Keys are disabled with the router's
// reason unless exactly one layer is selected.
import FlareModel
import SuiteUI
import SwiftUI

struct FlareInspectorGeometry: View {
    let rows: [AnimatedProperty]
    /// Why a bar can't act, and why a keyframe button can't; nil while it can.
    let rowHelp: String?
    let keyHelp: String?
    let perform: @MainActor (FlareIntent) -> Void

    var body: some View {
        InspectorSection("Transform") {
            ForEach(rows, id: \.name) { row in
                FlareGeometryRow(row: row, rowHelp: rowHelp, keyHelp: keyHelp, perform: perform)
            }
        }
    }
}

/// One TRANSFORM property: its bar and its keyframe button.
struct FlareGeometryRow: View {
    let row: AnimatedProperty
    let rowHelp: String?
    let keyHelp: String?
    let perform: @MainActor (FlareIntent) -> Void
    /// The stored value the current scrub started from; nil between scrubs.
    @State private var start: Double?

    /// Shown units per stored unit: opacity is stored 0...1 and shown 0...100 %.
    private var scale: Double { row.unit == "%" ? 100 : 1 }

    var body: some View {
        HStack(spacing: SuiteSpacing.xs) {
            InspectorSliderRow(
                row.title, value: (row.value ?? 0) * scale,
                in: row.range.lowerBound * scale...row.range.upperBound * scale,
                step: 1 / pow(10, Double(max(row.decimals, 0))), unit: row.unit, decimals: row.decimals,
                keyed: row.keyState == .keyedHere, mixed: row.value == nil,
                onChange: { shown in
                    let from = start ?? row.value ?? 0
                    start = from
                    perform(.inspector(.scrub(property: row.name, value: shown / scale, dragStart: from)))
                },
                onEnd: {
                    start = nil
                    perform(.inspector(.endScrub))
                })
                .accessibilityIdentifier("flare.inspector.\(row.name)")
                .disabled(rowHelp != nil)
                .help(rowHelp ?? row.title)
            KeyframeButton(
                row.title, id: "flare.inspector.\(row.name).key", state: Self.keyState(row.keyState),
                onToggle: { perform(.inspector(.toggleAnimated(row.name))) },
                onKey: { perform(.inspector(.toggleKey(row.name))) })
                .disabled(keyHelp != nil)
                .help(keyHelp ?? "Animate \(row.title)")
        }
    }

    /// SuiteUI's stopwatch state for the Model's key state.
    static func keyState(_ state: FlareModel.KeyState) -> SuiteUI.KeyState {
        switch state {
        case .notAnimated: .idle
        case .animated: .animated
        case .keyedHere: .keyedHere
        }
    }
}
