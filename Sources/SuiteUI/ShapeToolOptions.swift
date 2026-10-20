// ShapeToolOptions.swift (shape-tools SH-3): the shape tool's options. Six
// kind chips, each sending `.kind`, then the kind's rows: Polygon's Sides
// (3...64), Star's Points (3...64) and Inner ratio (10...100 %), Rectangle's
// Corner radius (0...500 pt) and Arrow's Head (2...200 pt); Ellipse and Line
// have none. A row's bar takes one step past each end of its range, so a
// value typed or scrubbed out of range reaches `change`, which sends the
// clamped value's intent (none when the spec already has it) and shows the
// help under the row: `ShapeRules.help` for the typed value, else the range
// ("Type a number from 3 to 64"). Identifiers: `suite.shape.chip-<kind>`,
// `suite.shape.<row>` and `suite.shape.help`. The rows and `change` are plain
// values so tests read them; the view keeps only the refusal it shows.
import SuiteKernel
import SwiftUI

/// One numeric option a shape kind shows.
public struct ShapeOptionRow: Hashable, Sendable, Identifiable {
    public enum Field: String, Hashable, Sendable { case sides, points, innerRatio = "inner-ratio", cornerRadius = "corner-radius", head }

    public let field: Field, title: String, range: ClosedRange<Double>, unit: String
    public var id: Field { field }
    public var identifier: String { "suite.shape.\(field.rawValue)" }
    /// What the row's bar takes: one past each end, so an out-of-range value is seen, not clamped silently.
    public var entry: ClosedRange<Double> { (range.lowerBound - 1)...(range.upperBound + 1) }

    static let counts = Double(ShapeRules.counts.lowerBound)...Double(ShapeRules.counts.upperBound)
    public static let sides = ShapeOptionRow(field: .sides, title: "Sides", range: counts, unit: "")
    public static let points = ShapeOptionRow(field: .points, title: "Points", range: counts, unit: "")
    public static let innerRatio = ShapeOptionRow(
        field: .innerRatio, title: "Inner ratio", range: (ShapeRules.ratios.lowerBound * 100)...(ShapeRules.ratios.upperBound * 100),
        unit: "%")
    public static let cornerRadius = ShapeOptionRow(field: .cornerRadius, title: "Corner radius", range: 0...500, unit: "pt")
    public static let head = ShapeOptionRow(field: .head, title: "Head", range: 2...200, unit: "pt")

    /// The rows `kind` shows, top to bottom.
    public static func rows(_ kind: ShapeKind) -> [ShapeOptionRow] {
        switch kind {
        case .polygon: [sides]
        case .star: [points, innerRatio]
        case .rectangle: [cornerRadius]
        case .arrow: [head]
        case .ellipse, .line: []
        }
    }

    /// The row's value in `spec`, as the row shows it (the ratio in percent).
    public func value(_ spec: ShapeSpec) -> Double {
        switch field {
        case .sides: Double(spec.sides)
        case .points: Double(spec.points)
        case .innerRatio: spec.innerRatio * 100
        case .cornerRadius: spec.cornerRadius
        case .head: spec.head
        }
    }

    /// The intent setting the row to `value`, a value inside `entry`.
    public func intent(_ value: Double) -> ShapeIntent {
        let shown = NumericInput.clamp(value, to: entry)
        switch field {
        case .sides: return .sides(Int(shown.rounded()))
        case .points: return .points(Int(shown.rounded()))
        case .innerRatio: return .innerRatio(shown / 100)
        case .cornerRadius: return .cornerRadius(shown)
        case .head: return .head(shown)
        }
    }

    /// `spec` with the row at `value`, unclamped, so `ShapeRules.help` can name what is wrong with it.
    func spec(_ spec: ShapeSpec, at value: Double) -> ShapeSpec {
        let shown = NumericInput.clamp(value, to: entry)
        var next = spec
        switch field {
        case .sides: next.sides = Int(shown.rounded())
        case .points: next.points = Int(shown.rounded())
        case .innerRatio: next.innerRatio = shown / 100
        case .cornerRadius: next.cornerRadius = shown
        case .head: next.head = shown
        }
        return next
    }
}

public struct ShapeToolOptions: View {
    let spec: ShapeSpec, help: String?, onIntent: @MainActor (ShapeIntent) -> Void
    /// The row whose last value was out of range, and the help under it. Presentation state only.
    @State private var refusal: Refusal?

    public init(spec: ShapeSpec, help: String?, onIntent: @escaping @MainActor (ShapeIntent) -> Void) {
        self.init(spec: spec, help: help, refused: nil, onIntent: onIntent)
    }

    /// Opens showing `refused`'s help under its row: for snapshots and tests.
    init(
        spec: ShapeSpec, help: String?, refused: (ShapeOptionRow.Field, String)?,
        onIntent: @escaping @MainActor (ShapeIntent) -> Void
    ) {
        (self.spec, self.help, self.onIntent) = (spec, help, onIntent)
        _refusal = State(initialValue: refused.map { Refusal(field: $0.0, text: $0.1) })
    }

    nonisolated static let kinds = ShapeKind.allCases.map {
        InspectorOption(id: $0, title: $0.rawValue.capitalized, identifier: "suite.shape.chip-\($0.rawValue)")
    }

    /// What `typed` in `row` does to `spec`: the intent for the value clamped into the row's range (nil when
    /// the spec has it already), and the help when `typed` was out of range.
    nonisolated static func change(_ row: ShapeOptionRow, typed: Double, spec: ShapeSpec) -> (intent: ShapeIntent?, help: String?) {
        let clamped = NumericInput.clamp(typed, to: row.range)
        let intent = abs(clamped - row.value(spec)) < 1e-9 ? nil : row.intent(clamped)
        guard !row.range.contains(typed) else { return (intent, nil) }
        let help = ShapeRules.help(row.spec(spec, at: typed)) ?? NumericInput.rangeHelp(row.range, decimals: 0, unit: row.unit)
        return (intent, help)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.s) {
            ChoiceChips(options: Self.kinds, selected: spec.kind) { kind in
                refusal = nil
                onIntent(.kind(kind))
            }
            ForEach(ShapeOptionRow.rows(spec.kind)) { row in
                InspectorSliderRow(row.title, value: row.value(spec), in: row.entry, step: 1, unit: row.unit, decimals: 0) { typed in
                    let change = Self.change(row, typed: typed, spec: spec)
                    refusal = change.help.map { Refusal(field: row.field, text: $0) }
                    if let intent = change.intent { onIntent(intent) }
                }
                .accessibilityIdentifier(row.identifier)
                if let refusal, refusal.field == row.field {
                    InspectorNote(refusal.text, kind: .error, identifier: "suite.shape.help")
                }
            }
            if let help { InspectorNote(help, kind: .secondary) }
        }
    }

    private struct Refusal: Equatable {
        let field: ShapeOptionRow.Field, text: String
    }
}
