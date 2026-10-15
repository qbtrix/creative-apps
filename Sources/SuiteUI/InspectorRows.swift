// InspectorRows.swift: the rows apps put in an inspector, in the filled
// Studio look of docs/design.md (Studio rows and chips, the look of Flare's
// easing editor). InspectorSection is a system DisclosureGroup under a small
// caps header (12 pt above, 4 below, no hairline): the whole header toggles
// it, the chevron shows on hover or while collapsed, and a Reset icon shows
// while `onReset` is given. The header button's identifier is
// `suite.inspector.section.<title slug>`, its Reset's that plus `.reset`
// (the app audit, #262). Its rows sit 4 pt apart, inset 12 pt from the
// panel's edges. InspectorRow is the filled 28 pt Studio row every other row
// shares: the label inside on the left in secondary text,
// the value on the right, the hover fill; an empty label puts a checkbox and
// its title on the left. InspectorSliderRow is the bar slider (ScrubField's
// bar look), InspectorStepperRow a bar slider with a step, and
// InspectorPickerRow a real Menu showing its choice on the right with a
// chevron. The one color row is in ColorWell.swift. Rows take the current
// value and an `onChange` closure, never a binding: apps can't bind to their
// Model. No glass. Components own presentation state only (a section's
// expansion, hover, a field's draft text).
import SwiftUI

/// A titled group of inspector rows the user can collapse. Pass `onReset`
/// only while the section differs from its defaults, so the icon shows
/// exactly when it would change something.
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
        DisclosureGroup(isExpanded: $isExpanded) {
            VStack(alignment: .leading, spacing: SuiteSpacing.xs) { content }
        } label: {
            Text(title)
        }
        .disclosureGroupStyle(InspectorDisclosureStyle(title: title, onReset: onReset))
        .padding(.horizontal, SuiteSpacing.m)
    }

    /// The header's accessibility identifier for a section titled `title`:
    /// its words in lower case joined by hyphens ("Hue/Saturation" gives
    /// `suite.inspector.section.hue-saturation`).
    nonisolated public static func headerIdentifier(_ title: String) -> String {
        let words = title.lowercased().split { !$0.isLetter && !$0.isNumber }
        return "suite.inspector.section." + words.joined(separator: "-")
    }
}

/// The section's rows flush under its header.
private struct InspectorDisclosureStyle: DisclosureGroupStyle {
    let title: String
    let onReset: (@MainActor () -> Void)?

    func makeBody(configuration: Configuration) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            InspectorSectionHeader(title: title, isExpanded: configuration.$isExpanded, onReset: onReset)
            if configuration.isExpanded { configuration.content }
        }
    }
}

/// The caps title and chevron (shown on hover or while collapsed) toggle the
/// section; the Reset icon sits after them.
private struct InspectorSectionHeader: View {
    let title: String
    @Binding var isExpanded: Bool
    let onReset: (@MainActor () -> Void)?
    @State private var hovering = false

    var body: some View {
        HStack(spacing: SuiteSpacing.xs) {
            Button {
                isExpanded.toggle()
            } label: {
                HStack(spacing: SuiteSpacing.xs) {
                    Text(title).textCase(.uppercase).tracking(SuiteSize.capsTracking)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .imageScale(.small)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        .opacity(hovering || !isExpanded ? 1 : 0)
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(.isHeader)
            .accessibilityValue(isExpanded ? "Expanded" : "Collapsed")
            .accessibilityIdentifier(InspectorSection<EmptyView>.headerIdentifier(title))
            if let onReset {
                Button(action: onReset) {
                    Image(systemName: "arrow.counterclockwise").imageScale(.small).contentShape(.rect)
                }
                .buttonStyle(.plain)
                .help("Reset \(title)")
                .accessibilityLabel("Reset \(title)")
                .accessibilityIdentifier(InspectorSection<EmptyView>.headerIdentifier(title) + ".reset")
            }
        }
        .font(SuiteFont.sectionCaps)
        .foregroundStyle(SuiteColor.secondaryText)
        .padding(.top, SuiteSpacing.m)
        .padding(.bottom, SuiteSpacing.xs)
        .onHover { hovering = $0 }
    }
}

/// One filled inspector row, the Studio row's 28 pt: `label` inside on
/// the left in secondary text, `value` on the right at SuiteSize.compactControl,
/// the hover fill. Disabled, the label dims to 40% with its control. An empty
/// label leaves `value` on the left, for a checkbox that carries its own title.
public struct InspectorRow<Value: View>: View {
    private let label: String
    private let value: Value
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(_ label: String, @ViewBuilder value: () -> Value) {
        self.label = label
        self.value = value()
    }

    public var body: some View {
        HStack(spacing: SuiteSpacing.s) {
            if !label.isEmpty {
                Text(label)
                    .font(SuiteFont.inspectorLabel)
                    .foregroundStyle(SuiteColor.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .layoutPriority(1)
                    .opacity(isEnabled ? 1 : SuiteColor.disabledOpacity)
            }
            value
                .font(SuiteFont.inspectorLabel)
                .frame(maxWidth: .infinity, alignment: label.isEmpty ? .leading : .trailing)
        }
        .padding(.horizontal, SuiteSpacing.m)
        .frame(minHeight: SuiteSize.studioRow)
        .background(hovering && isEnabled ? SuiteColor.field : SuiteColor.panelRaised, in: .rect(cornerRadius: SuiteRadius.row))
        .onHover { hovering = $0 }
        .animation(SuiteMotion.state(reduceMotion: reduceMotion), value: hovering)
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

/// A bar slider that moves by `step` within `range`, showing as many places
/// as the step needs. (Inspectors use no Stepper.)
public struct InspectorStepperRow: View {
    private let row: InspectorSliderRow

    public init(
        _ label: String, value: Double, in range: ClosedRange<Double>, step: Double = 1, unit: String = "",
        onChange: @escaping @MainActor (Double) -> Void
    ) {
        let places = step > 0 && step < 1 ? Int((-log10(step)).rounded(.up)) : 0
        row = InspectorSliderRow(label, value: value, in: range, step: step, unit: unit, decimals: places, onChange: onChange)
    }

    public var body: some View { row }
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

/// A filled row whose value is a real Menu: the choice on the right in
/// semibold with a chevron; the menu checks the current one.
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
            Menu {
                Picker(label, selection: Binding(get: { selection }, set: { onChange($0) })) {
                    ForEach(options) { Text($0.title).tag($0.id) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } label: {
                HStack(spacing: SuiteSpacing.xs) {
                    Text(options.first { $0.id == selection }?.title ?? "")
                        .font(SuiteFont.inspectorValue)
                    Image(systemName: "chevron.up.chevron.down").imageScale(.small).foregroundStyle(SuiteColor.textSecondary)
                }
                .contentShape(.rect)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
            .accessibilityLabel(label)
        }
    }
}
