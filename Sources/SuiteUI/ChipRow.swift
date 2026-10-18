// ChipRow.swift: the suite's chips. SuiteChipStyle is the one chip look, the
// Studio chips of Flare's easing presets, shared by PresetGrid (24 pt drawn,
// 28 to hit) and ChipRow (28 pt toggle chips): a filled rounded chip with a
// semibold caption in secondary text; hover takes the field fill and primary
// text; on is the selected well with a 1 pt accent border and primary text;
// disabled draws at 40%; state changes fade over 0.14 s (at once under
// `suiteReduceMotion`), each on/off fade a `fade-start`/`fade-end` pair on
// the chip probe's `chip` series, and each press a `press` sample (QB-S8,
// QB-S9; ChipProbe, which a probe host sets). ChipRow lays toggle chips in a row, as the timeline's
// toolbar does, each with an optional SF Symbol or an app's line mark
// (AppMark); each one reports On or Off. Chips are real Buttons, so Tab
// reaches them and Space presses them. Owns presentation state only: hover.
import SuiteModel
import SwiftUI

/// One toggle chip in a ChipRow.
public struct ChipItem<ID: Hashable & Sendable>: Identifiable, Sendable {
    public let id: ID
    public let title: String
    public let systemImage: String?
    /// The app whose line mark the chip shows (AppMark); it wins over `systemImage`.
    public let app: SuiteApp?
    public let isOn: Bool

    public init(id: ID, title: String, systemImage: String? = nil, app: SuiteApp? = nil, isOn: Bool) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.app = app
        self.isOn = isOn
    }

    /// What VoiceOver reads after the title.
    public var stateText: String { isOn ? "On" : "Off" }
}

/// A row of toggle chips; `onToggle` hears the chip pressed.
public struct ChipRow<ID: Hashable & Sendable>: View {
    private let chips: [ChipItem<ID>]
    private let onToggle: @MainActor (ID) -> Void
    @Environment(\.chipProbe) private var probe

    public init(_ chips: [ChipItem<ID>], onToggle: @escaping @MainActor (ID) -> Void) {
        self.chips = chips
        self.onToggle = onToggle
    }

    public var body: some View {
        HStack(spacing: SuiteSpacing.xs) {
            ForEach(chips) { chip in
                Button { ChipProbe.press(probe) { onToggle(chip.id) } } label: {
                    if let app = chip.app {
                        // A mark's 24-unit art fills less of its box than a symbol, so it takes the
                        // regular scale to read at a small symbol's size.
                        Label { Text(chip.title) } icon: { AppMark(app: app, style: .line).symbolSized() }
                    } else if let symbol = chip.systemImage {
                        Label(chip.title, systemImage: symbol).imageScale(.small)
                    } else {
                        Text(chip.title)
                    }
                }
                .buttonStyle(SuiteChipStyle(kind: .chip, isOn: chip.isOn))
                .accessibilityValue(chip.stateText)
                .accessibilityAddTraits(chip.isOn ? .isSelected : [])
            }
        }
    }
}

/// The chip look; `.preset` for PresetGrid, `.chip` for ChipRow.
struct SuiteChipStyle: ButtonStyle {
    enum Kind { case preset, chip }

    /// Side padding inside a preset, 4 pt so the widest preset ("Ease In-Out") fits its column of PresetGrid at the
    /// inspector's ideal width; the chips keep SuiteSpacing.s. PresetLabelFitTests holds the fit.
    static let presetPadding: CGFloat = SuiteSpacing.xs

    let kind: Kind
    let isOn: Bool

    func makeBody(configuration: Configuration) -> some View {
        ChipBody(configuration: configuration, kind: kind, isOn: isOn)
    }

    private struct ChipBody: View {
        let configuration: Configuration
        let kind: Kind
        let isOn: Bool
        @State private var hovering = false
        /// The on state drawn; it follows `isOn` through ChipProbe.fade, so the fade reports its marks.
        @State private var shownOn: Bool
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.suiteReduceMotion) private var reduceMotion
        @Environment(\.chipProbe) private var probe

        init(configuration: Configuration, kind: Kind, isOn: Bool) {
            self.configuration = configuration
            self.kind = kind
            self.isOn = isOn
            _shownOn = State(initialValue: isOn)
        }

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: SuiteRadius.row)
            let isOn = shownOn
            let lit = isOn || (hovering && isEnabled) || configuration.isPressed
            configuration.label
                .font(SuiteFont.caption.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(lit ? Color.primary : SuiteColor.secondaryText)
                .padding(.horizontal, kind == .preset ? SuiteChipStyle.presetPadding : SuiteSpacing.s)
                .frame(maxWidth: kind == .preset ? .infinity : nil)
                .frame(height: kind == .preset ? SuiteSize.preset : SuiteSize.chip)
                .background(fill, in: shape)
                .overlay {
                    if isOn { shape.strokeBorder(SuiteColor.accent, lineWidth: 1) }
                }
                .frame(height: kind == .preset ? SuiteSize.presetHit : SuiteSize.chip)
                .contentShape(.rect)
                .opacity(isEnabled ? 1 : SuiteColor.disabledOpacity)
                .onHover { hovering = $0 }
                .animation(SuiteMotion.state(reduceMotion: reduceMotion), value: hovering)
                .onChange(of: self.isOn) { _, new in
                    ChipProbe.fade(reduceMotion: reduceMotion, probe: probe) { shownOn = new }
                }
        }

        private var fill: Color {
            if shownOn { return SuiteColor.selectedWell }
            if hovering && isEnabled || configuration.isPressed { return SuiteColor.field }
            return SuiteColor.panelRaised
        }
    }
}

/// Where chips and presets report (a probe host sets it; nil records nothing):
/// a `fade-start`/`fade-end` mark pair on series `chip` per on/off change, and
/// a `press` sample from the press to the next main-actor turn, when the
/// host's update has run (as ScrubProbe does).
struct ChipProbe: Sendable {
    static let fadeSeries = "chip"
    static let pressSeries = "press"
    let record: @MainActor @Sendable (ProbeMark) -> Void
    let sample: @MainActor @Sendable (ProbeSample) -> Void

    /// Runs `change` under the state fade (none under Reduce Motion), marking its start and its end.
    @MainActor static func fade(reduceMotion: Bool, probe: ChipProbe?, _ change: () -> Void) {
        probe?.record(ProbeMark(name: "fade-start", series: fadeSeries, time: ProcessInfo.processInfo.systemUptime))
        // The completion runs exactly once: after the fade, or at once when nothing animates.
        withAnimation(SuiteMotion.state(reduceMotion: reduceMotion), change) {
            probe?.record(ProbeMark(name: "fade-end", series: fadeSeries, time: ProcessInfo.processInfo.systemUptime))
        }
    }

    /// Runs `action` for a press and reports its `press` sample.
    @MainActor static func press(_ probe: ChipProbe?, _ action: () -> Void) {
        let eventTime = ProcessInfo.processInfo.systemUptime
        action()
        guard let probe else { return }
        Task { @MainActor in
            probe.sample(ProbeSample(series: pressSeries, eventTime: eventTime, shownAt: ProcessInfo.processInfo.systemUptime))
        }
    }
}

extension EnvironmentValues {
    /// Where chips and presets report their fades and presses; nil records nothing.
    var chipProbe: ChipProbe? {
        get { self[ChipProbeKey.self] }
        set { self[ChipProbeKey.self] = newValue }
    }
}

private struct ChipProbeKey: EnvironmentKey {
    static let defaultValue: ChipProbe? = nil
}
