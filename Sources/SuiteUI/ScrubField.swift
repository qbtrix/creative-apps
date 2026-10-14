// ScrubField.swift: the one scrub control of an inspector, in two looks. As a
// ScrubField it is an exact number (X, Y, W, H): the value and its unit
// right-aligned on the row in semibold tabular figures, with no well of its
// own. As the bar slider (InspectorSliderRow) it is the Studio editor's
// number row, the look of Flare's easing rows: the whole 28 pt rounded row is
// the control, the label inside on the left, a lighter fill up to the value
// over five faint ticks, a thin marker at the value and the value on the
// right (docs/design.md, Studio rows and chips). Both share the rules: drag
// sideways to change the value (one step per point, Shift ten, Option a
// tenth; a modifier change re-anchors so nothing jumps), click or press
// Return to type (Return or a click away commits, Escape cancels), arrows
// step with the same modifiers, and the bar takes Home and End. Hover shows a dotted underline under the
// value; focus draws the 2 pt accent ring 1 pt outside; disabled draws at 40%.
// A ScrubTrack lets the bar move along a non-linear track (Photo's log gamma).
// Values go out through `onChange` already clamped and snapped (ScrubValue,
// NumericInput), then `onEnd` once per drag, key or typed value, so a host
// makes each one undo step; closing the typing field without typing changes
// nothing, and a typed number commits even when it matches the opening text
// (NumericInput.committed). The bar is a real slider to
// VoiceOver and XCUI (an accessibility representation), spoken with its unit.
// Owns presentation state only: the typed draft and whether it was edited,
// the drag anchor, hover.
import AppKit
import SwiftUI

public struct ScrubField: View {
    /// The bar slider's extras; nil draws the plain exact-number field.
    struct Bar {
        var keyed = false
        var mixed = false
        var track: ScrubTrack?
        /// A state drawn as if it were live, for the component snapshots.
        var preview: Preview?
    }

    enum Preview { case hover, focus, dragging, editing }

    private let label: String
    private let value: Double
    private let range: ClosedRange<Double>
    private let step: Double
    private let unit: String
    private let decimals: Int
    private let onChange: @MainActor (Double) -> Void
    private let onEnd: @MainActor () -> Void
    private let bar: Bar?
    @State private var draft: String?
    @State private var edited = false
    @State private var anchor: (position: Double, x: CGFloat, multiplier: Double)?
    @State private var hovering = false
    @FocusState private var isTyping: Bool
    @FocusState private var isFocused: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// `label` names the field for VoiceOver and the typing field; it is not
    /// drawn (InspectorRow draws the label). `step` defaults to
    /// ScrubValue.defaultStep(for: range). `decimals` is how many places it
    /// shows; typing may still give more.
    public init(
        _ label: String, value: Double, in range: ClosedRange<Double>, step: Double? = nil, unit: String = "",
        decimals: Int = 2, onChange: @escaping @MainActor (Double) -> Void
    ) {
        self.init(label, value: value, in: range, step: step, unit: unit, decimals: decimals, bar: nil, onChange: onChange)
    }

    init(
        _ label: String, value: Double, in range: ClosedRange<Double>, step: Double?, unit: String, decimals: Int,
        bar: Bar?, onChange: @escaping @MainActor (Double) -> Void, onEnd: @escaping @MainActor () -> Void = {}
    ) {
        self.label = label
        self.value = value
        self.range = range
        self.step = step ?? ScrubValue.defaultStep(for: range)
        self.unit = unit
        self.decimals = decimals
        self.onChange = onChange
        self.onEnd = onEnd
        self.bar = bar
        switch bar?.preview {
        case .hover: _hovering = State(initialValue: true)
        case .dragging: _anchor = State(initialValue: (value, 0, 1))
        case .editing: _draft = State(initialValue: NumericInput.format(value))
        default: break
        }
    }

    private var track: ScrubTrack {
        bar?.track ?? ScrubTrack(positions: range, step: step, position: { $0 }, value: { $0 })
    }

    public var body: some View {
        let editing = draft != nil
        let ring = isFocused || editing || bar?.preview == .focus
        let radius = bar == nil ? SuiteRadius.field : SuiteRadius.row
        Group {
            if let bar { barBody(bar) } else { valueText(SuiteColor.textPrimary) }
        }
        .lineLimit(1)
        .contentShape(.rect)
        .overlay {
            if ring {
                let out = SuiteSize.focusRingGap + SuiteSize.focusRing / 2
                RoundedRectangle(cornerRadius: radius + out)
                    .stroke(SuiteColor.accent, lineWidth: SuiteSize.focusRing)
                    .padding(-out)
            }
        }
        .opacity(isEnabled ? 1 : SuiteColor.disabledOpacity)
        .pointerStyle(editing || !isEnabled ? nil : .columnResize)
        .gesture(scrub, isEnabled: !editing && isEnabled)
        .focusable(!editing && isEnabled, interactions: .activate)
        .focused($isFocused)
        .focusEffectDisabled()
        .onHover { hovering = $0 }
        .onKeyPress(keys: [.upArrow, .downArrow, .leftArrow, .rightArrow, .home, .end, .return, .space]) { press($0) }
        .animation(SuiteMotion.state(reduceMotion: reduceMotion), value: hovering)
        .animation(SuiteMotion.state(reduceMotion: reduceMotion), value: anchor == nil)
        .help(label)
        .modifier(ScrubAccessibility(
            label: label, spoken: NumericInput.spoken(value, decimals: decimals, unit: unit), isBar: bar != nil,
            editing: editing, track: track, position: track.position(value), adjust: adjust))
    }

    /// The bar slider, drawn as the Studio editor's number row (Flare's easing
    /// rows): a 28 pt filled rounded row, a lighter fill up to the value over
    /// five faint ticks between the label and the value, and a thin marker at
    /// the value, accent while dragged.
    private func barBody(_ bar: Bar) -> some View {
        let dragging = anchor != nil
        let keyed = bar.keyed && !dragging
        let fraction = ScrubValue.fraction(track.position(value), in: track.positions)
        return GeometryReader { geo in
            let x = geo.size.width * fraction
            ZStack(alignment: .leading) {
                if !bar.mixed {
                    Rectangle().fill(dragging ? SuiteColor.studioFillActive : SuiteColor.studioFill).frame(width: x)
                }
                // Five ticks across the stretch between the label and the value.
                let lane = (start: SuiteSpacing.xxl + SuiteSpacing.s, end: geo.size.width - SuiteSpacing.xxl - SuiteSpacing.l)
                ForEach(0..<5) { tick in
                    Circle()
                        .fill(Color.primary.opacity(0.22))
                        .frame(width: SuiteSize.studioTick, height: SuiteSize.studioTick)
                        .position(x: lane.start + (lane.end - lane.start) * CGFloat(tick) / 4, y: geo.size.height / 2)
                }
                if !bar.mixed {
                    Rectangle()
                        .fill(dragging ? SuiteColor.accent : keyed ? SuiteColor.stateKeyed : Color.primary.opacity(0.55))
                        .frame(width: SuiteSize.studioTick, height: SuiteSize.studioRow - SuiteSpacing.m)
                        .position(x: min(max(x, SuiteSize.studioTick), geo.size.width - SuiteSize.studioTick), y: geo.size.height / 2)
                }
                HStack {
                    Text(label).font(SuiteFont.inspectorLabel).foregroundStyle(SuiteColor.secondaryText)
                    Spacer(minLength: SuiteSpacing.s)
                    valueText(keyed ? SuiteColor.stateKeyed : Color.primary, mixed: bar.mixed).fixedSize()
                }
                .padding(.horizontal, SuiteSpacing.m)
            }
        }
        .frame(height: SuiteSize.studioRow)
        .background(hovering && !dragging && isEnabled ? SuiteColor.field : SuiteColor.panelRaised)
        .clipShape(RoundedRectangle(cornerRadius: SuiteRadius.row))
    }

    /// The value with its unit, or the typing field on its inset well.
    @ViewBuilder
    private func valueText(_ color: Color, mixed: Bool = false) -> some View {
        if draft != nil {
            TextField(label, text: Binding(get: { draft ?? "" }, set: {
                draft = $0
                edited = true
            }))
                .textFieldStyle(.plain)
                .labelsHidden()
                .multilineTextAlignment(.trailing)
                .font(SuiteFont.inspectorValue)
                .foregroundStyle(SuiteColor.textPrimary)
                .focused($isTyping)
                .task { await takeFocus() }
                .onSubmit { commit(refocus: true) }
                .onExitCommand {
                    draft = nil
                    isFocused = true
                }
                .onChange(of: isTyping) { _, typing in if !typing { commit() } }
                .padding(.horizontal, SuiteSpacing.xs)
                .frame(width: SuiteSize.inspectorField)
                .background(SuiteColor.fieldActive, in: .rect(cornerRadius: SuiteRadius.field))
        } else {
            Text(mixed ? "Mixed" : NumericInput.text(value, decimals: decimals, unit: unit))
                .font(SuiteFont.inspectorValue)
                .foregroundStyle(color)
                .underline(hovering && isEnabled, pattern: .dot)
                .frame(minWidth: bar == nil ? SuiteSize.inspectorField : nil, alignment: .trailing)
                .background {
                    // The well while scrubbing reaches past the text, so the value never moves.
                    if bar == nil && anchor != nil {
                        RoundedRectangle(cornerRadius: SuiteRadius.field).fill(SuiteColor.fieldActive).padding(-SuiteSpacing.xs)
                    }
                }
        }
    }

    /// A press that moves 2 points sideways starts a scrub from there; one
    /// that doesn't is a click and opens the typing field.
    private var scrub: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                guard anchor != nil || abs(drag.translation.width) >= 2 else { return }
                let flags = NSEvent.modifierFlags
                let multiplier = ScrubValue.multiplier(shift: flags.contains(.shift), option: flags.contains(.option))
                if anchor?.multiplier != multiplier {
                    anchor = (track.position(value), drag.translation.width, multiplier)
                }
                guard let anchor else { return }
                set(position: ScrubValue.dragged(
                    from: anchor.position, by: Double(drag.translation.width - anchor.x), step: track.step,
                    multiplier: multiplier, in: track.positions))
            }
            .onEnded { _ in
                if anchor == nil { beginTyping() } else { onEnd() }
                anchor = nil
            }
    }

    private func press(_ press: KeyPress) -> KeyPress.Result {
        guard draft == nil, isEnabled else { return .ignored }
        let key: ScrubKey
        switch press.key {
        case .upArrow, .rightArrow: key = .increment
        case .downArrow, .leftArrow: key = .decrement
        case .home where bar != nil: key = .home
        case .end where bar != nil: key = .end
        case .return, .space:
            beginTyping()
            return .handled
        default: return .ignored
        }
        set(position: ScrubValue.pressed(
            key, from: track.position(value), step: track.step, shift: press.modifiers.contains(.shift),
            option: press.modifiers.contains(.option), in: track.positions))
        onEnd()
        return .handled
    }

    /// VoiceOver's increment and decrement, and XCUI's adjust, on the bar.
    private func adjust(_ position: Double) {
        set(position: position)
        onEnd()
    }

    private func set(position: Double) {
        let next = NumericInput.clamp(track.value(position), to: range)
        if next != value { onChange(next) }
    }

    /// Asks for the keyboard until the typing field has it; a request made as it
    /// appears is refused while the canvas holds the keys (as DesignTextEditor).
    /// ponytail: polls up to a third of a second, until SwiftUI can wait for focus.
    private func takeFocus() async {
        for _ in 0..<10 where !isTyping && !Task.isCancelled {
            isTyping = true
            try? await Task.sleep(for: .milliseconds(30))
        }
    }

    /// Swaps in the typing field; it takes focus as it appears.
    private func beginTyping() {
        guard isEnabled else { return }
        draft = NumericInput.format(value)
        edited = false
    }

    private func commit(refocus: Bool = false) {
        guard let text = draft else { return }
        draft = nil
        if refocus { isFocused = true }
        let parsed = NumericInput.committed(text, in: range, keeping: value, edited: edited)
        guard parsed != value else { return }
        onChange(parsed)
        onEnd()
    }
}

/// The field is one adjustable element; the bar is a real slider over its
/// track (so XCUI finds `sliders[label]`), except while typing, when the
/// text field shows through.
private struct ScrubAccessibility: ViewModifier {
    let label: String
    let spoken: String
    let isBar: Bool
    let editing: Bool
    let track: ScrubTrack
    let position: Double
    let adjust: @MainActor (Double) -> Void

    func body(content: Content) -> some View {
        if isBar && !editing {
            content.accessibilityRepresentation {
                Slider(
                    value: Binding(get: { position }, set: { adjust($0) }), in: track.positions,
                    step: track.step > 0 && track.step.isFinite ? track.step : 1
                ) {
                    Text(label)
                }
                .accessibilityValue(spoken)
            }
        } else {
            content
                .accessibilityElement(children: editing ? .contain : .ignore)
                .accessibilityLabel(label)
                .accessibilityValue(spoken)
                .accessibilityAdjustableAction { direction in
                    let key: ScrubKey = direction == .increment ? .increment : .decrement
                    guard direction == .increment || direction == .decrement else { return }
                    adjust(ScrubValue.pressed(key, from: position, step: track.step, in: track.positions))
                }
        }
    }
}
