// KeyframeButton.swift: the keyframe toggle beside an animatable property
// (docs/design.md, Anatomy of the controls). A 28 pt circle on the Studio fill
// with the stopwatch: idle in secondary text (not animated), filled in the
// keyed color once animated, and on the keyed tint while a key sits at the
// playhead. Beside it a 28 pt slot always holds room for the key-here
// diamond, so the row never changes width while the timeline scrubs: empty
// while not animated, a hollow diamond to add a key at the playhead, a filled
// one to remove it. Hover fills the circle; disabled draws at 40%, and with
// `unavailableHelp` both buttons show that reason as their tooltip, so a
// mouse user learns why the pair does nothing (`help(_:state:unavailable:)`). KeyState
// carries the symbol, color and VoiceOver value of each state. Given an `id`,
// the stopwatch reads it as its accessibility identifier and the diamond reads
// `diamondID(id)`. Set the id here, never on the KeyframeButton from outside:
// an identifier on the pair lands on both buttons, and once the diamond
// appears the stopwatch reads 56 pt wide, over the diamond (#1282). Owns
// presentation state only: hover.
import SwiftUI

/// Whether a property is animated, and whether a key sits at the playhead.
public enum KeyState: Sendable, CaseIterable {
    case idle, animated, keyedHere

    public var symbol: String { self == .idle ? "stopwatch" : "stopwatch.fill" }
    public var color: Color { self == .idle ? SuiteColor.textSecondary : SuiteColor.stateKeyed }
    public var voiceOverValue: String {
        switch self {
        case .idle: "Not animated"
        case .animated: "Animated"
        case .keyedHere: "Keyed at this frame"
        }
    }

    /// The key-here diamond: none while not animated, hollow to add a key,
    /// filled to remove the one at the playhead.
    public var diamond: (symbol: String, action: String)? {
        switch self {
        case .idle: nil
        case .animated: ("diamond", "Add Key")
        case .keyedHere: ("diamond.fill", "Remove Key")
        }
    }
}

public struct KeyframeButton: View {
    private let property: String
    private let id: String?
    private let state: KeyState
    private let unavailableHelp: String?
    private let onToggle: @MainActor () -> Void
    private let onKey: @MainActor () -> Void
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// `onToggle` turns animation on or off for `property`; `onKey` adds or
    /// removes the key at the playhead. `id` identifies the stopwatch, and
    /// `diamondID(id)` the diamond. `unavailableHelp` is why the pair can't act
    /// while the host disables it; both buttons show it as their tooltip.
    public init(
        _ property: String, id: String? = nil, state: KeyState, unavailableHelp: String? = nil,
        onToggle: @escaping @MainActor () -> Void, onKey: @escaping @MainActor () -> Void
    ) {
        self.property = property
        self.id = id
        self.state = state
        self.unavailableHelp = unavailableHelp
        self.onToggle = onToggle
        self.onKey = onKey
    }

    /// The stopwatch's and the diamond's tooltips: each one's action, or `unavailable` on both while it can't act.
    nonisolated public static func help(
        _ property: String, state: KeyState, unavailable: String? = nil
    ) -> (stopwatch: String, diamond: String?) {
        let diamond = state.diamond.map { unavailable ?? "\($0.action) for \(property)" }
        return (unavailable ?? (state == .idle ? "Animate \(property)" : "Stop Animating \(property)"), diamond)
    }

    public var body: some View {
        let help = Self.help(property, state: state, unavailable: unavailableHelp)
        return HStack(spacing: 0) {
            Button(action: onToggle) {
                Image(systemName: state.symbol)
                    .imageScale(.small)
                    .foregroundStyle(state.color)
                    .frame(width: SuiteSize.keyframeButton, height: SuiteSize.keyframeButton)
                    .background(
                        state == .keyedHere ? SuiteColor.keyedTint : hovering && isEnabled ? SuiteColor.field : SuiteColor.panelRaised,
                        in: Circle())
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .onHover { hovering = $0 }
            .help(help.stopwatch)
            .accessibilityLabel("Animate \(property)")
            .accessibilityValue(state.voiceOverValue)
            .accessibilityIdentifier(id ?? state.symbol)
            ZStack {
                if let diamond = state.diamond {
                    Button(action: onKey) {
                        Image(systemName: diamond.symbol)
                            .imageScale(.small)
                            .foregroundStyle(SuiteColor.stateKeyed)
                            .frame(width: SuiteSize.keyframeButton, height: SuiteSize.keyframeButton)
                            .contentShape(.rect)
                    }
                    .buttonStyle(.plain)
                    .help(help.diamond ?? "")
                    .accessibilityLabel("\(diamond.action), \(property)")
                    .accessibilityIdentifier(id.map(Self.diamondID) ?? diamond.symbol)
                }
            }
            .frame(width: SuiteSize.keyframeButton, height: SuiteSize.keyframeButton)
        }
        .opacity(isEnabled ? 1 : SuiteColor.disabledOpacity)
        .animation(SuiteMotion.state(reduceMotion: reduceMotion), value: hovering)
        .animation(SuiteMotion.state(reduceMotion: reduceMotion), value: state)
    }

    /// The diamond's identifier beside the stopwatch identified `id`.
    public static func diamondID(_ id: String) -> String { "\(id).diamond" }
}
