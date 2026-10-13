// ScrubField.swift: the compact number field of a dense inspector. Drag it
// sideways to change the value (one step per point; Shift is ten steps,
// Option a tenth), click it to type an exact number, Return or a click away to
// commit, Escape to cancel. Up and Down arrows nudge by one step when it has
// keyboard focus. It shows `decimals` places (NumericInput.format): whole for
// percent and degrees, one for pixels and EV. At rest it is a Text on a flat
// field well, so snapshots draw it. Values out through `onChange` only, already clamped (ScrubValue,
// NumericInput); the Model clamps again. Owns presentation state only: the
// typed draft and the drag anchor. Closing the typing field on the text it
// opened with changes nothing (NumericInput.committed).
import AppKit
import SwiftUI

public struct ScrubField: View {
    private let label: String
    private let value: Double
    private let range: ClosedRange<Double>
    private let step: Double
    private let unit: String
    private let decimals: Int
    private let onChange: @MainActor (Double) -> Void
    @State private var draft: String?
    @State private var anchor: (value: Double, x: CGFloat, multiplier: Double)?
    @FocusState private var isTyping: Bool
    @Environment(\.isEnabled) private var isEnabled

    /// `label` names the field for VoiceOver and the typing field; it is not
    /// drawn (InspectorRow draws the label). `step` defaults to
    /// ScrubValue.defaultStep(for: range). `decimals` is how many places it
    /// shows; typing may still give more.
    public init(
        _ label: String, value: Double, in range: ClosedRange<Double>, step: Double? = nil, unit: String = "",
        decimals: Int = 2, onChange: @escaping @MainActor (Double) -> Void
    ) {
        self.label = label
        self.value = value
        self.range = range
        self.step = step ?? ScrubValue.defaultStep(for: range)
        self.unit = unit
        self.decimals = decimals
        self.onChange = onChange
    }

    public var body: some View {
        HStack(spacing: SuiteSpacing.xxs) {
            if draft != nil {
                TextField(label, text: Binding(get: { draft ?? "" }, set: { draft = $0 }))
                    .textFieldStyle(.plain)
                    .labelsHidden()
                    .focused($isTyping)
                    .onAppear { isTyping = true }
                    .onSubmit(commit)
                    .onExitCommand { draft = nil }
                    .onChange(of: isTyping) { _, typing in if !typing { commit() } }
            } else {
                Text(NumericInput.format(value, decimals: decimals)).frame(maxWidth: .infinity, alignment: .trailing)
            }
            if !unit.isEmpty {
                Text(unit).foregroundStyle(SuiteColor.secondaryText)
            }
        }
        .font(SuiteFont.inspectorValue)
        .multilineTextAlignment(.trailing)
        .lineLimit(1)
        .foregroundStyle(isEnabled ? Color.primary : SuiteColor.secondaryText)
        .padding(.horizontal, SuiteSpacing.xs)
        .padding(.vertical, SuiteSpacing.xxs)
        .frame(width: SuiteSize.inspectorField)
        .background(
            draft != nil || anchor != nil ? SuiteColor.fieldActive : SuiteColor.field,
            in: RoundedRectangle(cornerRadius: SuiteRadius.field)
        )
        .contentShape(.rect)
        .pointerStyle(draft == nil ? .columnResize : nil)
        .gesture(scrub, isEnabled: draft == nil)
        .focusable(draft == nil, interactions: .activate)
        .onKeyPress(.upArrow) { nudge(1) }
        .onKeyPress(.downArrow) { nudge(-1) }
        .onKeyPress(.return) {
            guard draft == nil else { return .ignored }
            beginTyping()
            return .handled
        }
        .help(label)
        .accessibilityElement(children: draft == nil ? .ignore : .contain)
        .accessibilityLabel(label)
        .accessibilityValue(unit.isEmpty ? shown : "\(shown) \(unit)")
        .accessibilityAdjustableAction { direction in
            _ = nudge(direction == .increment ? 1 : direction == .decrement ? -1 : 0)
        }
    }

    private var shown: String { NumericInput.format(value, decimals: decimals) }

    /// A press that moves 2 points sideways starts a scrub from there; one
    /// that doesn't is a click and opens the typing field. A modifier change
    /// mid-drag re-anchors at the current value, so the number never jumps.
    private var scrub: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                guard anchor != nil || abs(drag.translation.width) >= 2 else { return }
                let flags = NSEvent.modifierFlags
                let multiplier = ScrubValue.multiplier(shift: flags.contains(.shift), option: flags.contains(.option))
                if anchor?.multiplier != multiplier {
                    anchor = (value, drag.translation.width, multiplier)
                }
                guard let anchor else { return }
                let next = ScrubValue.dragged(
                    from: anchor.value, by: Double(drag.translation.width - anchor.x), step: step,
                    multiplier: multiplier, in: range)
                if next != value { onChange(next) }
            }
            .onEnded { _ in
                if anchor == nil { beginTyping() }
                anchor = nil
            }
    }

    private func nudge(_ steps: Int) -> KeyPress.Result {
        guard draft == nil, isEnabled else { return .ignored }
        let next = ScrubValue.dragged(from: value, by: Double(steps), step: step, in: range)
        if next != value { onChange(next) }
        return .handled
    }

    /// Swaps in the typing field; it takes focus as it appears.
    private func beginTyping() {
        guard isEnabled else { return }
        draft = NumericInput.format(value)
    }

    private func commit() {
        guard let text = draft else { return }
        draft = nil
        let parsed = NumericInput.committed(text, in: range, keeping: value)
        if parsed != value { onChange(parsed) }
    }
}
