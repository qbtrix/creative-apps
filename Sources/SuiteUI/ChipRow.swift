// ChipRow.swift: the suite's chips. SuiteChipStyle is the one chip look, the
// Studio chips of Flare's easing presets, shared by PresetGrid (24 pt drawn,
// 28 to hit) and ChipRow (28 pt toggle chips): a filled rounded chip with a
// semibold caption in secondary text; hover takes the field fill and primary
// text; on is the selected well with a 1 pt accent border and primary text;
// disabled draws at 40%; state changes fade over 0.14 s (at once under
// Reduce Motion). ChipRow lays toggle
// chips in a row, as the timeline's toolbar does; each one reports On or Off.
// Chips are real Buttons, so Tab reaches them and Space presses them. Owns
// presentation state only: hover.
import SwiftUI

/// One toggle chip in a ChipRow.
public struct ChipItem<ID: Hashable & Sendable>: Identifiable, Sendable {
    public let id: ID
    public let title: String
    public let systemImage: String?
    public let isOn: Bool

    public init(id: ID, title: String, systemImage: String? = nil, isOn: Bool) {
        self.id = id
        self.title = title
        self.systemImage = systemImage
        self.isOn = isOn
    }

    /// What VoiceOver reads after the title.
    public var stateText: String { isOn ? "On" : "Off" }
}

/// A row of toggle chips; `onToggle` hears the chip pressed.
public struct ChipRow<ID: Hashable & Sendable>: View {
    private let chips: [ChipItem<ID>]
    private let onToggle: @MainActor (ID) -> Void

    public init(_ chips: [ChipItem<ID>], onToggle: @escaping @MainActor (ID) -> Void) {
        self.chips = chips
        self.onToggle = onToggle
    }

    public var body: some View {
        HStack(spacing: SuiteSpacing.xs) {
            ForEach(chips) { chip in
                Button { onToggle(chip.id) } label: {
                    if let symbol = chip.systemImage {
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
        @Environment(\.isEnabled) private var isEnabled
        @Environment(\.accessibilityReduceMotion) private var reduceMotion

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: SuiteRadius.row)
            let lit = isOn || (hovering && isEnabled) || configuration.isPressed
            configuration.label
                .font(SuiteFont.caption.weight(.semibold))
                .lineLimit(1)
                .foregroundStyle(lit ? Color.primary : SuiteColor.secondaryText)
                .padding(.horizontal, SuiteSpacing.s)
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
                .animation(SuiteMotion.state(reduceMotion: reduceMotion), value: isOn)
        }

        private var fill: Color {
            if isOn { return SuiteColor.selectedWell }
            if hovering && isEnabled || configuration.isPressed { return SuiteColor.field }
            return SuiteColor.panelRaised
        }
    }
}
