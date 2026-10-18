// TransportCapsule.swift: the shared transport (#340, UC13): Go to Start,
// Previous Frame, Play/Pause, Next Frame, Go to End and Loop, then the
// timecode, on one `row` capsule. It owns no playback: the host keeps the
// TransportState and applies each callback (steps as a frame delta), and the
// capsule reads only `stepping.face(state)`: the play title, the reason every
// button shows while nothing can play, the timecode and its tooltip. Steps and
// ends are round SuiteSize.transportButton buttons on HoverButtonStyle in
// secondary ink (tertiary while disabled); Play is the larger round
// borderedProminent button in accentFill; Loop is a button-style Toggle. Each
// control's tooltip is its reason or else its title, and it registers that
// reason under `suite.transport.<id>`; each press reports a `press` sample
// and the play glyph's swap fades under `suiteReduceMotion` with a
// `fade-start`/`fade-end` pair on series `transport`.
import SwiftUI

public struct TransportCapsule: View {
    /// The series the play glyph's fade marks report on.
    static let fadeSeries = "transport"

    /// One control: what it is, how it looks, and why it can't act (nil when it can).
    struct Item: Identifiable, Equatable {
        enum Kind: Equatable { case start, step(Int), play, end, loop }
        let id: String
        let kind: Kind
        let title: String
        let systemImage: String
        let help: String?

        /// The tooltip: the reason while disabled, else the title.
        var tooltip: String { help ?? title }
    }

    let state: TransportState
    let face: TransportFace
    private let onPlay: @MainActor () -> Void
    private let onStep: @MainActor (Int) -> Void
    private let onStart: @MainActor () -> Void
    private let onEnd: @MainActor () -> Void
    private let onLoop: @MainActor (Bool) -> Void
    @State private var shownPlaying: Bool
    @Environment(\.chipProbe) private var probe
    @Environment(\.suiteReduceMotion) private var reduceMotion

    /// `onStep` gets the frame delta (-1 or +1); `onLoop` the new loop state. The host applies each.
    public init(
        state: TransportState, stepping: some TransportStepping = SuiteTransport(),
        onPlay: @escaping @MainActor () -> Void, onStep: @escaping @MainActor (Int) -> Void,
        onStart: @escaping @MainActor () -> Void, onEnd: @escaping @MainActor () -> Void,
        onLoop: @escaping @MainActor (Bool) -> Void
    ) {
        self.state = state
        self.face = stepping.face(state)
        self.onPlay = onPlay
        self.onStep = onStep
        self.onStart = onStart
        self.onEnd = onEnd
        self.onLoop = onLoop
        _shownPlaying = State(initialValue: state.isPlaying)
    }

    /// The controls in order, each with the face's reason.
    var items: [Item] {
        let why = face.unavailableHelp
        return [
            Item(id: "suite.transport.start", kind: .start, title: "Go to Start", systemImage: "backward.end.fill", help: why),
            Item(id: "suite.transport.back", kind: .step(-1), title: "Previous Frame", systemImage: "backward.frame.fill", help: why),
            Item(id: "suite.transport.play", kind: .play, title: face.playTitle,
                 systemImage: shownPlaying ? "pause.fill" : "play.fill", help: why),
            Item(id: "suite.transport.forward", kind: .step(1), title: "Next Frame", systemImage: "forward.frame.fill", help: why),
            Item(id: "suite.transport.end", kind: .end, title: "Go to End", systemImage: "forward.end.fill", help: why),
            Item(id: "suite.transport.loop", kind: .loop, title: "Loop", systemImage: "repeat", help: why),
        ]
    }

    /// The timecode split at " / " into the current value and the rest ("" when there is no separator).
    nonisolated static func timecodeParts(_ timecode: String) -> (current: String, total: String) {
        guard let cut = timecode.range(of: " / ") else { return (timecode, "") }
        return (String(timecode[..<cut.lowerBound]), String(timecode[cut.lowerBound...]))
    }

    public var body: some View {
        HStack(spacing: SuiteSpacing.xxs) {
            ForEach(items) { item in
                button(item)
                    .disabled(item.help != nil)
                    // After .disabled, so the tooltip still shows on a disabled control.
                    .help(item.tooltip)
                    .accessibilityLabel(item.title)
                    .suiteControl(id: item.id, enabled: item.help == nil, reason: item.help)
            }
            timecode
        }
        .padding(SuiteSpacing.xxs)
        .background(SuiteColor.row, in: Capsule())
        .fixedSize()
        .accessibilityElement(children: .contain)
        .onChange(of: state.isPlaying) { _, playing in fadePlayGlyph(to: playing) }
    }

    private var timecode: some View {
        let parts = Self.timecodeParts(face.timecode)
        return HStack(spacing: 0) {
            Text(verbatim: parts.current).foregroundStyle(SuiteColor.textPrimary)
            Text(verbatim: parts.total).foregroundStyle(SuiteColor.textSecondary)
        }
        .font(SuiteFont.timecode)
        .padding(.horizontal, SuiteSpacing.s)
        .help(face.timecodeHelp ?? "")
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: face.timecode))
        .accessibilityIdentifier("suite.transport.timecode")
    }

    @ViewBuilder private func button(_ item: Item) -> some View {
        let glyph = Label(item.title, systemImage: item.systemImage).labelStyle(.iconOnly)
        switch item.kind {
        case .play:
            Button { ChipProbe.press(probe, onPlay) } label: {
                glyph.frame(width: SuiteSize.playButton, height: SuiteSize.playButton)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .tint(SuiteColor.accentFill)
            .accessibilityValue(Text(verbatim: state.isPlaying ? "Playing" : "Paused"))
            .accessibilityAddTraits(state.isPlaying ? .isSelected : [])
        case .loop:
            let loops = Binding(get: { state.loops }, set: { new in ChipProbe.press(probe) { onLoop(new) } })
            Toggle(isOn: loops) { glyph.frame(width: SuiteSize.transportButton, height: SuiteSize.transportButton) }
                .toggleStyle(.button)
                .buttonBorderShape(.circle)
                .tint(SuiteColor.accent)
        case .start, .end, .step:
            Button { ChipProbe.press(probe) { act(item.kind) } } label: {
                glyph.frame(width: SuiteSize.transportButton, height: SuiteSize.transportButton).contentShape(.circle)
            }
            .buttonStyle(HoverButtonStyle())
            .foregroundStyle(item.help == nil ? SuiteColor.textSecondary : SuiteColor.textTertiary)
        }
    }

    private func act(_ kind: Item.Kind) {
        switch kind {
        case .start: onStart()
        case .end: onEnd()
        case .step(let frames): onStep(frames)
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
