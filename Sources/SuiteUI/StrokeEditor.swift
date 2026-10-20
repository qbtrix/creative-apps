// StrokeEditor.swift (stroke-style SS-2 placeholder, SS-3 view): the one stroke editor every app shows under its
// gradient editor in the paint section (packet docs/blueprints/suiteui/features/stroke-style.md). It never edits a
// document: each gesture is one kernel `StrokeIntent` sent through `onIntent`, which the app runs as its stroke
// command. The placeholder reads the stroke out, row by row (Color, Width, Join, Cap, Dash and, unless `showsTrim` is
// false, Trim), with `help` or `dashHelp` as a note under them; no row is a control yet. SS-3 makes the rows controls with the `suite.stroke.*` identifiers and sends their intents.
import SuiteKernel
import SwiftUI

public struct StrokeEditor: View {
    private let stroke: VectorStroke?
    /// Why nothing can be stroked now; nil when it can.
    private let help: String?
    /// Why the dash and trim rows can't act (`StrokeRules.waitingCore` until SS-7); nil when they can.
    private let dashHelp: String?
    /// False hides the trim rows (Design, whose shapes don't animate).
    private let showsTrim: Bool
    /// Called once per gesture sample with its intent; SS-3 wires the rows to it.
    private let onIntent: @MainActor (StrokeIntent) -> Void

    /// `showsTrim: false` hides the trim rows (Design); `dashHelp` disables the dash and trim rows with it.
    public init(stroke: VectorStroke?, help: String?, dashHelp: String?, showsTrim: Bool = true,
                onIntent: @escaping @MainActor (StrokeIntent) -> Void) {
        self.stroke = stroke
        self.help = help
        self.dashHelp = dashHelp
        self.showsTrim = showsTrim
        self.onIntent = onIntent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            if let stroke {
                InspectorRow("Color") { StrokeEditorValue(StrokeEditorText.color(stroke.color)) }
                InspectorRow("Width") { StrokeEditorValue(StrokeEditorText.points(stroke.width)) }
                InspectorRow("Join") { StrokeEditorValue(stroke.join.rawValue.capitalized) }
                InspectorRow("Cap") { StrokeEditorValue(stroke.cap.rawValue.capitalized) }
                InspectorRow("Dash") { StrokeEditorValue(StrokeRules.preset(of: stroke).rawValue.capitalized) }
                if showsTrim {
                    InspectorRow("Trim") { StrokeEditorValue(StrokeEditorText.trim(StrokeRules.trim(of: stroke))) }
                }
                if let dashHelp { InspectorNote(dashHelp) }
            } else {
                InspectorNote("No stroke.")
            }
            if let help { InspectorNote(help) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("suite.stroke")
    }
}

/// One row's value as plain text, trailing in the row.
private struct StrokeEditorValue: View {
    let text: String

    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .foregroundStyle(SuiteColor.secondaryText)
            .lineLimit(1)
    }
}

/// The placeholder's row texts.
enum StrokeEditorText {
    /// "#RRGGBB", with the opacity as a percentage when it isn't opaque.
    static func color(_ color: FillColor) -> String {
        let hex = HexColor(Color.Resolved(red: Float(color.r), green: Float(color.g), blue: Float(color.b))).text
        guard color.a.isFinite, color.a < 1 else { return hex }
        return "\(hex) \(Int((max(color.a, 0) * 100).rounded()))%"
    }

    /// "2 pt", or "0.5 pt" for a width between whole points.
    static func points(_ width: Double) -> String {
        NumericInput.text(width, decimals: width.rounded() == width ? 0 : 1, unit: "pt")
    }

    /// "Start 0%, End 100%, Offset 0°"; the whole path when there is no trim.
    static func trim(_ trim: (start: Double, end: Double, offset: Double)?) -> String {
        let (start, end, offset) = trim ?? (0, 1, 0)
        return "Start \(percent(start)), End \(percent(end)), Offset \(NumericInput.text(offset * 360, decimals: 0, unit: "°"))"
    }

    private static func percent(_ fraction: Double) -> String { NumericInput.text(fraction * 100, decimals: 0, unit: "%") }
}
