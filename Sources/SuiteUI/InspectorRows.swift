// InspectorRows.swift: the rows apps put in SuiteWindow's inspector, grouped in
// collapsible InspectorSections. Each row is one LabeledContent around a system
// control (Slider, Stepper, ColorPicker, menu Picker). Rows take the current
// value and an `onChange` closure, never a binding: apps can't bind to their
// Model. Typed numbers go through NumericInput, so they reach `onChange`
// clamped, and text that isn't a number keeps the old value; the Model clamps
// again. No glass: the inspector column is system chrome already. Components
// own presentation state only (a section's expansion, a field's draft text).
import SwiftUI

/// A titled group of inspector rows the user can collapse.
public struct InspectorSection<Content: View>: View {
    private let title: String
    private let content: Content
    @State private var isExpanded: Bool

    public init(_ title: String, isExpanded: Bool = true, @ViewBuilder content: () -> Content) {
        self.title = title
        self._isExpanded = State(initialValue: isExpanded)
        self.content = content()
    }

    public var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: SuiteSpacing.s) { content }
                .padding(.top, SuiteSpacing.xs)
        } label: {
            Text(title).font(SuiteFont.headline)
        }
    }
}

/// Label, Slider and a numeric field with an optional unit.
public struct InspectorSliderRow: View {
    private let label: String
    private let value: Double
    private let range: ClosedRange<Double>
    private let unit: String
    private let onChange: @MainActor (Double) -> Void

    public init(
        _ label: String, value: Double, in range: ClosedRange<Double>, unit: String = "",
        onChange: @escaping @MainActor (Double) -> Void
    ) {
        self.label = label
        self.value = value
        self.range = range
        self.unit = unit
        self.onChange = onChange
    }

    public var body: some View {
        LabeledContent(label) {
            HStack(spacing: SuiteSpacing.s) {
                Slider(
                    value: Binding(get: { value }, set: { onChange(NumericInput.clamp($0, to: range)) }),
                    in: range
                )
                .accessibilityLabel(label)
                InspectorNumberField(label: label, value: value, range: range, unit: unit, onChange: onChange)
            }
        }
    }
}

/// Label, a numeric field and a Stepper that moves by `step` within `range`.
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
        LabeledContent(label) {
            HStack(spacing: SuiteSpacing.xs) {
                InspectorNumberField(label: label, value: value, range: range, unit: unit, onChange: onChange)
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
        LabeledContent(label) {
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
        LabeledContent(label) {
            Picker(label, selection: Binding(get: { selection }, set: { onChange($0) })) {
                ForEach(options) { Text($0.title).tag($0.id) }
            }
            .pickerStyle(.menu)
            .labelsHidden()
        }
    }
}

/// The numeric field the slider and stepper rows share. While the user types
/// it shows their draft; on Return or losing focus the draft goes through
/// NumericInput and, if that changes the value, out through `onChange`.
private struct InspectorNumberField: View {
    let label: String
    let value: Double
    let range: ClosedRange<Double>
    let unit: String
    let onChange: @MainActor (Double) -> Void
    @State private var draft: String?
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: SuiteSpacing.xxs) {
            TextField(label, text: Binding(get: { draft ?? NumericInput.format(value) }, set: { draft = $0 }))
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .font(SuiteFont.monospacedDigits)
                .frame(width: SuiteSize.inspectorField)
                .focused($isFocused)
                .onSubmit(commit)
                .onChange(of: isFocused) { _, focused in
                    if !focused { commit() }
                }
            if !unit.isEmpty {
                Text(unit).font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText)
            }
        }
    }

    private func commit() {
        guard let text = draft else { return }
        draft = nil
        let parsed = NumericInput.parse(text, in: range, keeping: value)
        if parsed != value { onChange(parsed) }
    }
}
