// GradientEditor.swift (gradient-fill GF-2 placeholder, GF-3 view): the one gradient editor every app shows in its
// paint section (packet docs/blueprints/suiteui/features/gradient-fill.md). It never edits a document: each gesture is
// one kernel `GradientIntent` sent through `onIntent`, which the app runs as its fill command. The placeholder reads the
// fill out, row by row (Type, Stops and, for a linear fill unless `showsAngle` is false, Angle); no row is a control
// yet. GF-3 makes them the stop bar, colour row, angle row and type switch with the `suite.gradient.*` identifiers.
import SuiteKernel
import SwiftUI

public struct GradientEditor: View {
    private let fill: Fill
    /// The box the fill's points are in.
    private let box: Rect
    /// False hides the angle row (a tool whose drag sets the line, Photo's Gradient tool).
    private let showsAngle: Bool
    /// The fill types the switch offers.
    private let types: [FillType]
    /// Called once per gesture sample with its intent; GF-3 wires the controls to it.
    private let onIntent: @MainActor (GradientIntent) -> Void

    /// `showsAngle: false` for a tool whose drag sets the line (Photo's Gradient tool); `types` limits the switch.
    public init(fill: Fill, box: Rect, showsAngle: Bool = true, types: [FillType] = FillType.allCases,
                onIntent: @escaping @MainActor (GradientIntent) -> Void) {
        self.fill = fill
        self.box = box
        self.showsAngle = showsAngle
        self.types = types
        self.onIntent = onIntent
    }

    public var body: some View {
        let type = GradientRules.type(of: fill)
        VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            InspectorRow("Type") { GradientEditorValue(GradientEditorText.type(type)) }
            if type != .solid {
                InspectorRow("Stops") { GradientEditorValue("\(fill.stops.count)") }
            }
            if showsAngle, type == .linear {
                InspectorRow("Angle") { GradientEditorValue(GradientEditorText.angle(GradientRules.angle(of: fill))) }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("suite.gradient")
    }
}

/// One row's value as plain text, trailing in the row.
private struct GradientEditorValue: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .foregroundStyle(SuiteColor.secondaryText)
            .lineLimit(1)
    }
}

/// The editor's texts.
enum GradientEditorText {
    /// "Solid", "Linear" or "Radial".
    static func type(_ type: FillType) -> String { type.rawValue.capitalized }

    /// "45°", rounded to a whole degree; "–" when there is no angle.
    static func angle(_ degrees: Double?) -> String {
        guard let degrees, degrees.isFinite else { return "–" }
        return NumericInput.text(degrees, decimals: 0, unit: "°")
    }
}
