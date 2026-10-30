// TransportCapsule.swift: the one transport every app draws (#340, UC13; Halo's
// look, kept canonical 2026-10-30): Go to Start, Previous Frame, Play/Pause,
// Next Frame, Go to End and Loop as plain icon-only SF Symbol buttons, each at
// least a SuiteSize.pillHit square, edge to edge, in secondary ink (tertiary
// while disabled, accent for Loop while on), then the timecode when the host
// gives one. Play shows pause.fill while playing, reads "Playing"/"Paused"
// and is selected while playing; Loop is a button-style Toggle reading
// "On"/"Off". With `pill` the row sits in a status pill (StatusPillFace,
// compact controls) the way ViewerStatusBar draws one; a host that already
// gives it a pill, or wants the bare row, passes false. It owns no playback:
// values in, intents out. The host words each control (TransportControl: id,
// title, reason) and applies each callback (steps as a frame delta); the
// `state:`/`stepping:` init words them from `stepping.face(state)` under
// `suite.transport.<id>` with the face's reason on every control and its
// timecode. Each control's tooltip is its reason or else its title, and it
// registers that reason with `.suiteControl`; each press reports a `press`
// sample and the play glyph's swap fades under `suiteReduceMotion` with a
// `fade-start`/`fade-end` pair on series `transport`.
import SwiftUI

/// The transport's controls, in the order they sit.
public enum TransportButton: CaseIterable, Sendable {
    case start, previous, play, next, end, loop

    /// The title the `state:` init gives it (Play's is the face's).
    var title: String {
        switch self {
        case .start: "Go to Start"
        case .previous: "Previous Frame"
        case .play: "Play"
        case .next: "Next Frame"
        case .end: "Go to End"
        case .loop: "Loop"
        }
    }

    /// The `suite.transport.<id>` suffix the `state:` init gives it.
    var suiteID: String {
        switch self {
        case .previous: "back"
        case .next: "forward"
        default: "\(self)"
        }
    }
}

/// How the host words one control: its control id, its title, and why it can't act (nil when it can).
public struct TransportControl: Equatable, Sendable {
    public let id: String
    public let title: String
    public let reason: String?

    public init(id: String, title: String, reason: String? = nil) {
        self.id = id
        self.title = title
        self.reason = reason
    }
}

public struct TransportCapsule: View {
    /// The series the play glyph's fade marks report on.
    static let fadeSeries = "transport"

    /// One control: which it is, how it reads, and why it can't act (nil when it can).
    struct Item: Identifiable, Equatable {
        let button: TransportButton
        let id: String
        let title: String
        let systemImage: String
        let help: String?

        /// The tooltip: the reason while disabled, else the title.
        var tooltip: String { help ?? title }
    }

    let isPlaying: Bool
    let loops: Bool
    let pill: Bool
    /// The timecode source; nil shows no timecode.
    let face: TransportFace?
    private let controls: [TransportControl]
    private let onPlay: @MainActor () -> Void
    private let onStep: @MainActor (Int) -> Void
    private let onStart: @MainActor () -> Void
    private let onEnd: @MainActor () -> Void
    private let onLoop: @MainActor (Bool) -> Void
    @State private var shownPlaying: Bool
    @Environment(\.chipProbe) private var probe
    @Environment(\.suiteReduceMotion) private var reduceMotion

    /// `control` words each button; `timecode` (a face) adds the timecode after them. `onStep` gets the frame
    /// delta (-1 or +1); `onLoop` the new loop state. The host applies each.
    public init(
        isPlaying: Bool, loops: Bool, pill: Bool = true, timecode: TransportFace? = nil,
        control: (TransportButton) -> TransportControl,
        onPlay: @escaping @MainActor () -> Void, onStep: @escaping @MainActor (Int) -> Void,
        onStart: @escaping @MainActor () -> Void, onEnd: @escaping @MainActor () -> Void,
        onLoop: @escaping @MainActor (Bool) -> Void
    ) {
        self.isPlaying = isPlaying
        self.loops = loops
        self.pill = pill
        self.face = timecode
        self.controls = TransportButton.allCases.map(control)
        self.onPlay = onPlay
        self.onStep = onStep
        self.onStart = onStart
        self.onEnd = onEnd
        self.onLoop = onLoop
        _shownPlaying = State(initialValue: isPlaying)
    }

    /// The suite's wording: `suite.transport.<id>`, the face's play title, its reason on every control, its timecode.
    public init(
        state: TransportState, stepping: some TransportStepping = SuiteTransport(),
        onPlay: @escaping @MainActor () -> Void, onStep: @escaping @MainActor (Int) -> Void,
        onStart: @escaping @MainActor () -> Void, onEnd: @escaping @MainActor () -> Void,
        onLoop: @escaping @MainActor (Bool) -> Void
    ) {
        let face = stepping.face(state)
        self.init(
            isPlaying: state.isPlaying, loops: state.loops, timecode: face,
            control: { button in
                TransportControl(id: "suite.transport.\(button.suiteID)",
                                 title: button == .play ? face.playTitle : button.title, reason: face.unavailableHelp)
            },
            onPlay: onPlay, onStep: onStep, onStart: onStart, onEnd: onEnd, onLoop: onLoop)
    }

    /// The controls in order, as the host worded them.
    var items: [Item] {
        zip(TransportButton.allCases, controls).map { button, control in
            Item(button: button, id: control.id, title: control.title,
                 systemImage: Self.symbol(button, playing: shownPlaying), help: control.reason)
        }
    }

    /// Each control's SF Symbol; Play's turns to pause while playing.
    nonisolated static func symbol(_ button: TransportButton, playing: Bool) -> String {
        switch button {
        case .start: "backward.end.fill"
        case .previous: "backward.frame.fill"
        case .play: playing ? "pause.fill" : "play.fill"
        case .next: "forward.frame.fill"
        case .end: "forward.end.fill"
        case .loop: "repeat"
        }
    }

    /// The timecode split at " / " into the current value and the rest ("" when there is no separator).
    nonisolated static func timecodeParts(_ timecode: String) -> (current: String, total: String) {
        guard let cut = timecode.range(of: " / ") else { return (timecode, "") }
        return (String(timecode[..<cut.lowerBound]), String(timecode[cut.lowerBound...]))
    }

    public var body: some View {
        if pill {
            StatusPillFace(.plain) { row }
                .frame(height: SuiteSize.pillHit)
                .controlSize(SuiteSize.compactControl)
        } else {
            row
        }
    }

    private var row: some View {
        HStack(spacing: 0) {
            ForEach(items) { item in
                control(item)
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    // A pill control's hit target: at least pillHit square (design.md, Symbols and controls).
                    .frame(minWidth: SuiteSize.pillHit, minHeight: SuiteSize.pillHit)
                    .contentShape(Rectangle())
                    .disabled(item.help != nil)
                    // Its own ink, so a pill's secondary text can't draw a disabled control as live.
                    .foregroundStyle(ink(item))
                    // After .disabled, so the tooltip still shows on a disabled control.
                    .help(item.tooltip)
                    .accessibilityLabel(item.title)
                    .accessibilityValue(Text(verbatim: value(item.button)))
                    .suiteControl(id: item.id, enabled: item.help == nil, reason: item.help)
            }
            if let face { timecode(face) }
        }
        .fixedSize()
        .accessibilityElement(children: .contain)
        .onChange(of: isPlaying) { _, playing in fadePlayGlyph(to: playing) }
    }

    private func timecode(_ face: TransportFace) -> some View {
        let parts = Self.timecodeParts(face.timecode)
        return HStack(spacing: 0) {
            Text(verbatim: parts.current).foregroundStyle(SuiteColor.textPrimary)
            Text(verbatim: parts.total).foregroundStyle(SuiteColor.textSecondary)
        }
        .font(SuiteFont.pill)
        .padding(.horizontal, SuiteSpacing.xxs)
        .help(face.timecodeHelp ?? "")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: face.timecode))
        .accessibilityIdentifier("suite.transport.timecode")
    }

    /// Loop is a button-style Toggle, so the system draws its on state; the rest are plain buttons.
    @ViewBuilder private func control(_ item: Item) -> some View {
        let glyph = Label(item.title, systemImage: item.systemImage)
        switch item.button {
        case .play:
            Button { ChipProbe.press(probe, onPlay) } label: { glyph }
                .accessibilityAddTraits(isPlaying ? .isSelected : [])
        case .loop:
            Toggle(isOn: Binding(get: { loops }, set: { new in ChipProbe.press(probe) { onLoop(new) } })) { glyph }
                .toggleStyle(.button)
                .tint(SuiteColor.accent)
        case .start, .previous, .next, .end:
            Button { ChipProbe.press(probe) { act(item.button) } } label: { glyph }
        }
    }

    /// Tertiary while disabled, accent for Loop while on, else secondary.
    private func ink(_ item: Item) -> Color {
        guard item.help == nil else { return SuiteColor.textTertiary }
        return item.button == .loop && loops ? SuiteColor.accent : SuiteColor.textSecondary
    }

    /// Play reads "Playing"/"Paused", Loop "On"/"Off"; the others no value.
    func value(_ button: TransportButton) -> String {
        switch button {
        case .play: isPlaying ? "Playing" : "Paused"
        case .loop: loops ? "On" : "Off"
        default: ""
        }
    }

    private func act(_ button: TransportButton) {
        switch button {
        case .start: onStart()
        case .end: onEnd()
        case .previous: onStep(-1)
        case .next: onStep(1)
        case .play, .loop: break
        }
    }

    /// Swaps the play glyph under the state fade (none under Reduce Motion), marking its start and end.
    private func fadePlayGlyph(to playing: Bool) {
        let now = { ProcessInfo.processInfo.systemUptime }
        probe?.record(ProbeMark(name: "fade-start", series: Self.fadeSeries, time: now()))
        withAnimation(SuiteMotion.state(reduceMotion: reduceMotion), { shownPlaying = playing }) {
            probe?.record(ProbeMark(name: "fade-end", series: Self.fadeSeries, time: now()))
        }
    }
}
