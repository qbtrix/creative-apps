// StrokeEditor.swift (stroke-style SS-3): the one stroke editor every app shows under its gradient editor in the
// paint section (packet docs/blueprints/suiteui/features/stroke-style.md). It never edits a document: each gesture
// sample is one kernel `StrokeIntent` sent through `onIntent`, which the app runs as its stroke command. The rows are
// the colour row (InspectorColorWellRow), Width (InspectorSliderRow, 0...1000 pt, "4 pt" or "0.5 pt"), Join and Cap
// (ChoiceChips on the rows' edges, each option explained in the row's tooltip), Dash
// (ChoiceChips of the presets, and for Custom a Dash and a Gap row), Trim Start and End (0...100 %) and Offset
// (−360...360 °), unless `showsTrim` is false, then Remove Stroke; with no stroke, Add Stroke alone. A scrub or a
// run of colour picks shares one drag token until its end, so the host folds it into one undo step. A row that can't
// act is disabled with its reason as its help: `help` for every row, "No stroke." without one, and `dashHelp` for the
// dash and trim rows (StrokeRules.waitingCore until SS-7), also shown as a note under them, and `styleHelp` for Join
// and Cap (an app whose stroke can't hold them yet), its note under the chips. Identifiers are
// `suite.stroke.<row>` (StrokeEditorRow), with `join.<join>`, `cap.<cap>` and `dash.<preset>` on the chips. The
// decisions live in StrokeEditorRules, which StrokeEditorTests drive; the view only lays the rows out.
import Foundation
import SuiteKernel
import SwiftUI

public struct StrokeEditor: View {
    private let rules: StrokeEditorRules
    /// Called once per gesture sample with its intent.
    private let onIntent: @MainActor (StrokeIntent) -> Void
    /// The open gesture's drag token; nil between gestures.
    @State private var drag: String?

    /// `showsTrim: false` hides the trim rows (Design); `dashHelp` disables the dash and trim rows with it, and
    /// `styleHelp` the Join and Cap chips.
    public init(stroke: VectorStroke?, help: String?, dashHelp: String?, styleHelp: String? = nil, showsTrim: Bool = true,
                onIntent: @escaping @MainActor (StrokeIntent) -> Void) {
        rules = StrokeEditorRules(stroke: stroke, help: help, dashHelp: dashHelp, showsTrim: showsTrim, styleHelp: styleHelp)
        self.onIntent = onIntent
    }

    public var body: some View {
        let rows = rules.rows
        VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            if rows.contains(.color) { colorRow }
            if rows.contains(.width) {
                InspectorSliderRow("Width", value: rules.value(.width), in: StrokeRules.widths, step: 0.5, unit: "pt",
                                   decimals: StrokeEditorText.decimals(rules.value(.width)),
                                   onChange: { v in sample { rules.width(v, drag: $0) } }, onEnd: end)
                    .strokeRow(.width, rules)
            }
            if rows.contains(.join) {
                chips(.join, options: StrokeJoin.allCases.map { option($0.rawValue, "join") }, selected: rules.stroke?.join.rawValue) {
                    send(StrokeJoin(rawValue: $0).flatMap(rules.join))
                }
            }
            if rows.contains(.cap) {
                chips(.cap, options: StrokeCap.allCases.map { option($0.rawValue, "cap") }, selected: rules.stroke?.cap.rawValue) {
                    send(StrokeCap(rawValue: $0).flatMap(rules.cap))
                }
            }
            if rows.contains(.cap), let note = rules.styleNote { InspectorNote(note) }
            if rows.contains(.dash) {
                chips(.dash, options: DashPreset.allCases.map { option($0.rawValue, "dash") }, selected: rules.preset?.rawValue) {
                    send(DashPreset(rawValue: $0).flatMap(rules.dash))
                }
            }
            ForEach([StrokeEditorRow.dashLength, .gap, .trimStart, .trimEnd, .trimOffset].filter { rows.contains($0) }, id: \.self) { row in
                let spec = StrokeEditorRules.slider(row)
                InspectorSliderRow(spec.label, value: rules.value(row), in: spec.range, unit: spec.unit, decimals: spec.decimals,
                                   onChange: { v in sample { rules.edit(row, to: v, drag: $0) } }, onEnd: end)
                    .strokeRow(row, rules)
            }
            if rows.contains(.dash), let dashHelp = rules.dashHelp, rules.stroke != nil, rules.help == nil {
                InspectorNote(dashHelp)
            }
            if rows.contains(.add) { action(.add, "Add Stroke", systemImage: "plus") }
            if rows.contains(.remove) { action(.remove, "Remove Stroke", systemImage: "minus") }
            if let help = rules.help { InspectorNote(help) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("suite.stroke")
    }

    /// The colour row: a run of panel picks or one hex commit is one gesture.
    private var colorRow: some View {
        let reason = rules.reason(.color)
        return InspectorColorWellRow("Color", color: rules.hex, onChange: { hex in sample { rules.color(hex, drag: $0) } },
                                     onEnd: end)
            .hexIdentifier(StrokeEditorRow.color.identifier)
            .disabled(reason != nil)
            .help(reason ?? "")
            .suiteControl(id: StrokeEditorRow.color.identifier, enabled: reason == nil, reason: reason, identifies: false)
    }

    /// A labelled chip group in Design's style: the label above, the chips under it, on the other rows' edges.
    private func chips(_ row: StrokeEditorRow, options: [InspectorOption<String>], selected: String?,
                       onSelect: @escaping @MainActor (String) -> Void) -> some View {
        let reason = rules.reason(row)
        return VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            Text(StrokeEditorRules.label(row)).font(SuiteFont.inspectorLabel).foregroundStyle(SuiteColor.textSecondary)
            ChoiceChips(options: options, selected: selected, onSelect: onSelect)
                .disabled(reason != nil)
                .help(rules.chipsHelp(row))
                .accessibilityElement(children: .contain)
                .accessibilityLabel(StrokeEditorRules.label(row))
                .suiteControl(id: row.identifier, enabled: reason == nil, reason: reason)
        }
    }

    private func option(_ raw: String, _ group: String) -> InspectorOption<String> {
        InspectorOption(id: raw, title: raw.capitalized, identifier: "suite.stroke.\(group).\(raw)")
    }

    private func action(_ row: StrokeEditorRow, _ title: String, systemImage: String) -> some View {
        InspectorAction(ToolbarAction(title, systemImage: systemImage, unavailableHelp: rules.reason(row),
                                      identifier: row.identifier) { onIntent(row == .add ? .add : .remove) })
    }

    /// One gesture sample: the open token (opened on the first sample), then the one intent it asks for.
    private func sample(_ intent: (String) -> StrokeIntent?) {
        let token = StrokeEditorRules.token(drag)
        if drag == nil { drag = token }
        send(intent(token))
    }

    private func send(_ intent: StrokeIntent?) { if let intent { onIntent(intent) } }

    private func end() { if drag != nil { drag = nil } }
}

private extension View {
    /// A scrub row's identifier, its disabled state and its reason as help.
    func strokeRow(_ row: StrokeEditorRow, _ rules: StrokeEditorRules) -> some View {
        let reason = rules.reason(row)
        return disabled(reason != nil).help(reason ?? "")
            .suiteControl(id: row.identifier, enabled: reason == nil, reason: reason)
    }
}

/// One control of the editor, the last part of its identifier `suite.stroke.<row>`.
enum StrokeEditorRow: String, CaseIterable, Sendable {
    case add, color, width, join, cap, dash
    case dashLength = "dash-length", gap
    case trimStart = "trim-start", trimEnd = "trim-end", trimOffset = "trim-offset"
    case remove

    var identifier: String { "suite.stroke.\(rawValue)" }
    var isDashOrTrim: Bool { [.dash, .dashLength, .gap, .trimStart, .trimEnd, .trimOffset].contains(self) }
}

/// What the editor shows and asks for: which rows, why one can't act, each row's value, and the one intent a gesture
/// sample asks for (nil when the row can't act or the sample changes nothing).
struct StrokeEditorRules: Sendable {
    let stroke: VectorStroke?
    let help: String?
    let dashHelp: String?
    let showsTrim: Bool
    /// Why Join and Cap can't act, after `help` and "No stroke.".
    var styleHelp: String? = nil

    nonisolated static let noStroke = "No stroke."

    /// The rows on screen: Add Stroke alone without a stroke; Dash and Gap only for a custom pattern; trim unless hidden.
    var rows: [StrokeEditorRow] {
        guard let stroke else { return [.add] }
        var rows: [StrokeEditorRow] = [.color, .width, .join, .cap, .dash]
        if StrokeRules.preset(of: stroke) == .custom { rows += [.dashLength, .gap] }
        if showsTrim { rows += [.trimStart, .trimEnd, .trimOffset] }
        return rows + [.remove]
    }

    /// Why `row` can't act: `help`, then "No stroke.", then `dashHelp` for the dash and trim rows and `styleHelp` for
    /// Join and Cap; nil when it can.
    func reason(_ row: StrokeEditorRow) -> String? {
        if let help { return help }
        if row == .add { return stroke == nil ? nil : "The layer already has a stroke." }
        if stroke == nil { return Self.noStroke }
        if row == .join || row == .cap { return styleHelp }
        return row.isDashOrTrim ? dashHelp : nil
    }

    /// The note under Join and Cap: `styleHelp` once the rows are up and `help` says nothing.
    var styleNote: String? { stroke != nil && help == nil ? styleHelp : nil }

    var preset: DashPreset? { stroke.map(StrokeRules.preset(of:)) }

    /// The colour as the row's hex, black without a stroke.
    var hex: HexColor {
        guard let c = stroke?.color else { return .black }
        return HexColor(Color.Resolved(red: Float(c.r), green: Float(c.g), blue: Float(c.b)))
    }

    /// A slider row's value in the units it shows: points, percent, degrees.
    func value(_ row: StrokeEditorRow) -> Double {
        guard let stroke else { return 0 }
        let pattern = StrokeRules.dash(of: stroke).pattern
        let (start, end, offset) = StrokeRules.trim(of: stroke) ?? (0, 1, 0)
        switch row {
        case .width: return stroke.width
        case .dashLength: return pattern.first ?? 0
        case .gap: return pattern.dropFirst().first ?? 0
        case .trimStart: return start * 100
        case .trimEnd: return end * 100
        case .trimOffset: return offset * 360
        default: return 0
        }
    }

    func width(_ width: Double, drag: String?) -> StrokeIntent? {
        guard reason(.width) == nil, width.isFinite, StrokeRules.clampedWidth(width) != stroke?.width else { return nil }
        return .width(StrokeRules.clampedWidth(width), drag: drag)
    }

    /// The picked colour, keeping the stroke's opacity.
    func color(_ hex: HexColor, drag: String?) -> StrokeIntent? {
        guard reason(.color) == nil, let stroke, hex != self.hex else { return nil }
        let c = FillColor(r: Double(hex.red) / 255, g: Double(hex.green) / 255, b: Double(hex.blue) / 255, a: stroke.color.a)
        return .color(c, drag: drag)
    }

    func join(_ join: StrokeJoin) -> StrokeIntent? {
        reason(.join) == nil && join != stroke?.join ? .join(join) : nil
    }

    func cap(_ cap: StrokeCap) -> StrokeIntent? {
        reason(.cap) == nil && cap != stroke?.cap ? .cap(cap) : nil
    }

    /// A preset chip: its preset, or for Custom the current pattern (the dashed one when solid) to edit from.
    func dash(_ preset: DashPreset) -> StrokeIntent? {
        guard reason(.dash) == nil, let stroke, preset != self.preset else { return nil }
        guard preset == .custom else { return .dash(preset, pattern: nil) }
        let drawn = StrokeRules.dash(of: stroke).pattern
        return .dash(.custom, pattern: drawn.isEmpty ? StrokeRules.pattern(.dashed, width: stroke.width) : drawn)
    }

    /// A Dash, Gap or Trim row sample: the custom pattern, or the trim as fractions and an offset in turns.
    func edit(_ row: StrokeEditorRow, to value: Double, drag: String?) -> StrokeIntent? {
        guard reason(row) == nil, value.isFinite, value != self.value(row) else { return nil }
        switch row {
        case .dashLength: return .dash(.custom, pattern: [value, self.value(.gap)])
        case .gap: return .dash(.custom, pattern: [self.value(.dashLength), value])
        case .trimStart, .trimEnd, .trimOffset:
            var v = [StrokeEditorRow.trimStart, .trimEnd, .trimOffset].map { $0 == row ? value : self.value($0) }
            v = [v[0] / 100, v[1] / 100, v[2] / 360]
            return .trim(start: v[0], end: v[1], offset: v[2], drag: drag)
        default: return nil
        }
    }

    /// The open gesture's token, or a new one for its first sample.
    nonisolated static func token(_ open: String?) -> String { open ?? UUID().uuidString }

    /// A chip row's tooltip: why it can't act, or one line per option saying what it draws.
    func chipsHelp(_ row: StrokeEditorRow) -> String {
        if let reason = reason(row) { return reason }
        switch row {
        case .join: return StrokeJoin.allCases.map { Self.help(join: $0) }.joined(separator: "\n")
        case .cap: return StrokeCap.allCases.map { Self.help(cap: $0) }.joined(separator: "\n")
        default: return ""
        }
    }

    /// What a join draws at a corner: its line in the Join tooltip.
    nonisolated static func help(join: StrokeJoin) -> String {
        switch join.rawValue {
        case "miter": "Miter: sharp, pointed corners."
        case "round": "Round: rounded corners."
        case "bevel": "Bevel: corners cut off flat."
        default: "\(join.rawValue.capitalized): a corner style."
        }
    }

    /// What a cap draws at an open end: its line in the Cap tooltip.
    nonisolated static func help(cap: StrokeCap) -> String {
        switch cap.rawValue {
        case "butt": "Butt: the line ends exactly at its endpoint."
        case "round": "Round: a half circle past the endpoint."
        case "square": "Square: a half-width square past the endpoint."
        default: "\(cap.rawValue.capitalized): an end style."
        }
    }

    nonisolated static func label(_ row: StrokeEditorRow) -> String {
        switch row {
        case .dashLength: "Dash"
        case .trimStart: "Start"
        case .trimEnd: "End"
        case .trimOffset: "Offset"
        default: row.rawValue.capitalized
        }
    }

    /// A slider row's label, range, unit and places.
    nonisolated static func slider(_ row: StrokeEditorRow) -> (label: String, range: ClosedRange<Double>, unit: String, decimals: Int) {
        switch row {
        case .trimStart, .trimEnd: (label(row), 0...100, "%", 0)
        case .trimOffset: (label(row), -360...360, "°", 0)
        default: (label(row), StrokeRules.widths, "pt", 1)
        }
    }
}

/// Row texts other views share.
enum StrokeEditorText {
    /// "2 pt", or "0.5 pt" for a width between whole points.
    static func points(_ width: Double) -> String {
        NumericInput.text(width, decimals: decimals(width), unit: "pt")
    }

    /// The places a width shows, in this text and on the Width row: none for whole points, one between them.
    static func decimals(_ width: Double) -> Int { width.rounded() == width ? 0 : 1 }
}
