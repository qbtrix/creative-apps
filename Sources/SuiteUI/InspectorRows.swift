// InspectorRows.swift: the rows apps put in SuiteWindow's inspector, in the
// dense "Pro density" layout of docs/design.md. InspectorSection is a system
// DisclosureGroup with a flush header, a hairline above it and an optional
// Reset icon, never a card. InspectorRow is the two-column row: a right-aligned
// secondary label in the shared label column, then the value at the compact
// control size. InspectorSliderRow is the bar slider (ScrubField's bar look),
// a whole row on its own. The stepper, color and picker rows are InspectorRows
// around a system control; their numbers are ScrubFields. Rows take the current value and an
// `onChange` closure, never a binding: apps can't bind to their Model. No
// glass: the inspector column is system chrome already. Components own
// presentation state only (a section's expansion, a field's draft text).
import SwiftUI

/// A titled group of inspector rows the user can collapse: a hairline, then
/// a 22 pt header row (chevron and small semibold secondary title, plus a
/// small Reset icon while `onReset` is given), then the rows with no gaps
/// between them. Pass `onReset` only while the section differs from its
/// defaults, so the icon shows exactly when it would change something.
public struct InspectorSection<Content: View>: View {
    private let title: String
    private let onReset: (@MainActor () -> Void)?
    private let content: Content
    @State private var isExpanded: Bool

    public init(
        _ title: String, isExpanded: Bool = true, onReset: (@MainActor () -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.onReset = onReset
        self._isExpanded = State(initialValue: isExpanded)
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Divider()
            ZStack(alignment: .topTrailing) {
                DisclosureGroup(isExpanded: $isExpanded) {
                    VStack(alignment: .leading, spacing: 0) { content }
                        .padding(.bottom, SuiteSpacing.s)
                } label: {
                    Text(title).font(SuiteFont.inspectorSection).foregroundStyle(SuiteColor.secondaryText)
                }
                .disclosureGroupStyle(InspectorDisclosureStyle())
                if let onReset {
                    Button(action: onReset) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(SuiteFont.inspectorSection)
                            .foregroundStyle(SuiteColor.secondaryText)
                            .frame(height: SuiteSize.inspectorRow)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .help("Reset \(title)")
                    .accessibilityLabel("Reset \(title)")
                }
            }
        }
    }
}

/// The section header: the whole row toggles, the chevron turns, and the
/// content sits flush under it with no indent, so every row keeps the shared
/// label column.
private struct InspectorDisclosureStyle: DisclosureGroupStyle {
    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                configuration.isExpanded.toggle()
            } label: {
                HStack(spacing: SuiteSpacing.xs) {
                    Image(systemName: "chevron.right")
                        .font(SuiteFont.inspectorSection)
                        .foregroundStyle(SuiteColor.secondaryText)
                        .rotationEffect(.degrees(configuration.isExpanded ? 90 : 0))
                    configuration.label
                    Spacer(minLength: 0)
                }
                .frame(height: SuiteSize.inspectorRow)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            .accessibilityValue(configuration.isExpanded ? "Expanded" : "Collapsed")
            if configuration.isExpanded { configuration.content }
        }
    }
}

/// One two-column inspector row: `label` right-aligned in secondary text in
/// the shared label column (SuiteSize.inspectorLabelColumn), then `value`
/// filling the rest, at least SuiteSize.inspectorRow tall, with controls at
/// SuiteSize.compactControl. An empty label leaves the column blank, for a
/// checkbox that carries its own title.
public struct InspectorRow<Value: View>: View {
    private let label: String
    private let value: Value

    public init(_ label: String, @ViewBuilder value: () -> Value) {
        self.label = label
        self.value = value()
    }

    public var body: some View {
        HStack(spacing: SuiteSpacing.s) {
            Text(label)
                .font(SuiteFont.inspectorLabel)
                .foregroundStyle(SuiteColor.secondaryText)
                .lineLimit(1)
                .truncationMode(.middle)
                .frame(width: SuiteSize.inspectorLabelColumn, alignment: .trailing)
            value
                .font(SuiteFont.inspectorLabel)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: SuiteSize.inspectorRow)
        .controlSize(SuiteSize.compactControl)
    }
}

/// The bar slider: the whole 28 pt Studio row is the control, label inside on
/// the left, the value with its unit on the right, a fill and marker at the
/// value (ScrubField's bar look and rules, the look of Flare's easing rows). `decimals` places are shown (whole for
/// percent and degrees, one for pixels and EV). `keyed` draws the marker and
/// value in the keyed color, at the same width; `mixed` shows "Mixed" and no
/// marker. `track` moves it along a non-linear track. `onEnd` fires once per
/// drag, key or typed value.
public struct InspectorSliderRow: View {
    private let field: ScrubField

    public init(
        _ label: String, value: Double, in range: ClosedRange<Double>, step: Double? = nil, unit: String = "",
        decimals: Int = 2, keyed: Bool = false, mixed: Bool = false, track: ScrubTrack? = nil,
        onChange: @escaping @MainActor (Double) -> Void, onEnd: @escaping @MainActor () -> Void = {}
    ) {
        self.init(
            label, value: value, in: range, step: step, unit: unit, decimals: decimals,
            bar: ScrubField.Bar(keyed: keyed, mixed: mixed, track: track), onChange: onChange, onEnd: onEnd)
    }

    init(
        _ label: String, value: Double, in range: ClosedRange<Double>, step: Double?, unit: String, decimals: Int,
        bar: ScrubField.Bar, onChange: @escaping @MainActor (Double) -> Void, onEnd: @escaping @MainActor () -> Void
    ) {
        field = ScrubField(
            label, value: value, in: range, step: step, unit: unit, decimals: decimals, bar: bar, onChange: onChange,
            onEnd: onEnd)
    }

    public var body: some View { field }
}

/// Label, a ScrubField and a Stepper that move by `step` within `range`.
public struct InspectorStepperRow: View {
    private let label: String
    private let value: Double
    private let range: ClosedRange<Double>
    private let step: Double
    private let unit: String
    private let onChange: @MainActor (Double) -> Void

    public init(
        _ label: String, value: Double, in range: ClosedRange<Double>, step: Double = 1, unit: String = "",
        onChange: @escaping @MainActor (Double) -> Void
    ) {
        self.label = label
        self.value = value
        self.range = range
        self.step = step
        self.unit = unit
        self.onChange = onChange
    }

    public var body: some View {
        InspectorRow(label) {
            HStack(spacing: SuiteSpacing.xs) {
                ScrubField(label, value: value, in: range, step: step, unit: unit, onChange: onChange)
                Stepper(
                    label,
                    value: Binding(get: { value }, set: { onChange(NumericInput.clamp($0, to: range)) }),
                    in: range, step: step
                )
                .labelsHidden()
            }
        }
    }
}

/// Label and a ColorPicker.
public struct InspectorColorRow: View {
    private let label: String
    private let color: Color
    private let supportsOpacity: Bool
    private let onChange: @MainActor (Color) -> Void

    public init(
        _ label: String, color: Color, supportsOpacity: Bool = true,
        onChange: @escaping @MainActor (Color) -> Void
    ) {
        self.label = label
        self.color = color
        self.supportsOpacity = supportsOpacity
        self.onChange = onChange
    }

    public var body: some View {
        InspectorRow(label) {
            ColorPicker(
                label, selection: Binding(get: { color }, set: { onChange($0) }), supportsOpacity: supportsOpacity
            )
            .labelsHidden()
        }
    }
}

/// One choice in an InspectorPickerRow.
public struct InspectorOption<ID: Hashable & Sendable>: Identifiable, Hashable, Sendable {
    public let id: ID
    public let title: String

    public init(id: ID, title: String) {
        self.id = id
        self.title = title
    }
}

/// Label and a menu Picker over titled options.
public struct InspectorPickerRow<ID: Hashable & Sendable>: View {
    private let label: String
    private let options: [InspectorOption<ID>]
    private let selection: ID
    private let onChange: @MainActor (ID) -> Void

    public init(
        _ label: String, options: [InspectorOption<ID>], selection: ID,
        onChange: @escaping @MainActor (ID) -> Void
    ) {
        self.label = label
        self.options = options
        self.selection = selection
        self.onChange = onChange
    }

    public var body: some View {
        InspectorRow(label) {
            Picker(label, selection: Binding(get: { selection }, set: { onChange($0) })) {
                ForEach(options) { Text($0.title).tag($0.id) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }
}
