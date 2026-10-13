// StudioScrubRow.swift: the Studio editor's number row, a full-width rounded
// filled row that is its own slider. The label sits inside on the left, the
// value right-aligned in tabular figures, a lighter fill runs up to the value
// over faint tick dots, and a thin marker stands at the value (accent while
// dragged). Drag sideways to change it (ScrubValue: one step per point, Shift
// ten, Option a tenth); click it, or press Return or Space, to type an exact
// number; Up and Down nudge one step. Values go out clamped and snapped
// through `onChange`, then `onEnd` once per drag, nudge or typed value, so a
// host can make each one undo step. Owns presentation state only: the drag
// anchor and the typed draft.
import AppKit
import SwiftUI

public struct StudioScrubRow: View {
    private let label: String
    private let value: Double
    private let range: ClosedRange<Double>
    private let step: Double
    private let onChange: @MainActor (Double) -> Void
    private let onEnd: @MainActor () -> Void
    @State private var anchor: (start: Double, x: CGFloat, multiplier: Double)?
    @State private var draft: String?
    @FocusState private var typing: Bool

    public init(
        label: String, value: Double, range: ClosedRange<Double>, step: Double,
        onChange: @escaping @MainActor (Double) -> Void, onEnd: @escaping @MainActor () -> Void = {}
    ) {
        self.label = label
        self.value = value
        self.range = range
        self.step = step
        self.onChange = onChange
        self.onEnd = onEnd
    }

    /// How far along `range` the fill reaches, 0...1; 0 for an empty range or
    /// a value that isn't finite.
    nonisolated public static func fillFraction(_ value: Double, in range: ClosedRange<Double>) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0, span.isFinite, value.isFinite else { return 0 }
        return min(max((value - range.lowerBound) / span, 0), 1)
    }

    /// "0.25": a row's value with two decimals, in the person's locale.
    nonisolated public static func valueText(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(2)))
    }

    public var body: some View {
        GeometryReader { geo in
            let x = geo.size.width * Self.fillFraction(value, in: range)
            ZStack(alignment: .leading) {
                Rectangle().fill(anchor == nil ? SuiteColor.studioFill : SuiteColor.studioFillActive).frame(width: x)
                // Five ticks across the stretch between the label and the value.
                let lane = (start: SuiteSpacing.xxl + SuiteSpacing.s, end: geo.size.width - SuiteSpacing.xxl - SuiteSpacing.l)
                ForEach(0..<5) { tick in
                    Circle()
                        .fill(Color.primary.opacity(0.22))
                        .frame(width: SuiteSize.studioTick, height: SuiteSize.studioTick)
                        .position(x: lane.start + (lane.end - lane.start) * CGFloat(tick) / 4, y: geo.size.height / 2)
                }
                Rectangle()
                    .fill(anchor == nil ? Color.primary.opacity(0.55) : SuiteColor.accent)
                    .frame(width: SuiteSize.studioTick, height: SuiteSize.studioRow - SuiteSpacing.m)
                    .position(x: min(max(x, SuiteSize.studioTick), geo.size.width - SuiteSize.studioTick), y: geo.size.height / 2)
                HStack {
                    Text(label).font(SuiteFont.inspectorLabel).foregroundStyle(SuiteColor.secondaryText)
                    Spacer(minLength: SuiteSpacing.s)
                    if draft == nil {
                        Text(Self.valueText(value)).font(SuiteFont.inspectorValue.weight(.semibold))
                    } else {
                        TextField(label, text: Binding(get: { draft ?? "" }, set: { draft = $0 }))
                            .textFieldStyle(.plain)
                            .font(SuiteFont.inspectorValue.weight(.semibold))
                            .multilineTextAlignment(.trailing)
                            .focused($typing)
                            .onAppear { typing = true }
                            .onSubmit(commit)
                            .onExitCommand { draft = nil }
                            .onChange(of: typing) { _, now in if !now { commit() } }
                    }
                }
                .padding(.horizontal, SuiteSpacing.m)
            }
        }
        .frame(height: SuiteSize.studioRow)
        .background(SuiteColor.panelRaised)
        .clipShape(RoundedRectangle(cornerRadius: SuiteRadius.row))
        .contentShape(.rect)
        .pointerStyle(draft == nil ? .columnResize : nil)
        .gesture(drag, isEnabled: draft == nil)
        .focusable(draft == nil, interactions: .activate)
        .onKeyPress(.upArrow) { nudge(by: 1) }
        .onKeyPress(.downArrow) { nudge(by: -1) }
        .onKeyPress(keys: [.return, .space]) { _ in
            guard draft == nil else { return .ignored }
            draft = NumericInput.format(value)
            return .handled
        }
        .help(label)
        .accessibilityElement(children: draft == nil ? .ignore : .contain)
        .accessibilityLabel(label)
        .accessibilityValue(Self.valueText(value))
        .accessibilityAdjustableAction { direction in
            _ = nudge(by: direction == .increment ? 1 : direction == .decrement ? -1 : 0)
        }
    }

    /// Under 2 points of travel is a click, which opens typing; past that the
    /// row scrubs, re-anchoring when a modifier changes so the value never jumps.
    private var drag: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { drag in
                guard anchor != nil || abs(drag.translation.width) >= 2 else { return }
                let keys = NSEvent.modifierFlags
                let speed = ScrubValue.multiplier(shift: keys.contains(.shift), option: keys.contains(.option))
                if anchor?.multiplier != speed { anchor = (value, drag.translation.width, speed) }
                guard let anchor else { return }
                let moved = Double(drag.translation.width - anchor.x)
                let next = ScrubValue.dragged(from: anchor.start, by: moved, step: step, multiplier: speed, in: range)
                if next != value { onChange(next) }
            }
            .onEnded { _ in
                if anchor == nil { draft = NumericInput.format(value) } else { onEnd() }
                anchor = nil
            }
    }

    private func nudge(by steps: Int) -> KeyPress.Result {
        guard draft == nil, steps != 0 else { return .ignored }
        let next = ScrubValue.dragged(from: value, by: Double(steps), step: step, in: range)
        guard next != value else { return .handled }
        onChange(next)
        onEnd()
        return .handled
    }

    private func commit() {
        guard let text = draft else { return }
        draft = nil
        let typed = NumericInput.committed(text, in: range, keeping: value)
        guard typed != value else { return }
        onChange(typed)
        onEnd()
    }
}
