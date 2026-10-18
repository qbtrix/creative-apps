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
// appears the stopwatch reads 56 pt wide, over the diamond (#1282). The
// symbols, the diamond's action and the spoken value come from a
// KeyframeFacing (UC3; SuiteKeyframeFacing unless a gallery passes a Fake),
// and its fades follow `suiteReduceMotion`. With `registers` each button
// lists itself in `suite.controls` with its tooltip as the reason while it
// can't act (`entries`); hosts that list the pair themselves leave it off.
// Owns presentation state only: hover.
import SwiftUI

/// The live faces of the keyframe button (UC3): the stopwatch hollow while not
/// animated and filled once animated, the diamond hollow to add a key and
/// filled to remove the one at the playhead.
public struct SuiteKeyframeFacing: KeyframeFacing {
    public init() {}

    public func face(for presence: KeyPresence) -> KeyframeFace {
        switch presence {
        case .idle: KeyframeFace(symbol: "stopwatch", diamondSymbol: nil, diamondAction: nil, spoken: "Not animated")
        case .animated:
            KeyframeFace(symbol: "stopwatch.fill", diamondSymbol: "diamond", diamondAction: .add, spoken: "Animated")
        case .keyedHere:
            KeyframeFace(
                symbol: "stopwatch.fill", diamondSymbol: "diamond.fill", diamondAction: .remove,
                spoken: "Keyed at this frame")
        }
    }
}

extension KeyAction {
    /// The diamond's action as its tooltip and VoiceOver label name it.
    public var title: String { self == .add ? "Add Key" : "Remove Key" }
}

/// Whether a property is animated, and whether a key sits at the playhead.
public enum KeyState: Sendable, CaseIterable {
    case idle, animated, keyedHere

    /// The contract's presence for this state, one to one.
    public var presence: KeyPresence {
        switch self {
        case .idle: .idle
        case .animated: .animated
        case .keyedHere: .keyedHere
        }
    }

    public var symbol: String { SuiteKeyframeFacing().face(for: presence).symbol }
    public var color: Color { self == .idle ? SuiteColor.textSecondary : SuiteColor.stateKeyed }
    public var voiceOverValue: String { SuiteKeyframeFacing().face(for: presence).spoken }

    /// The key-here diamond: none while not animated, hollow to add a key,
    /// filled to remove the one at the playhead.
    public var diamond: (symbol: String, action: String)? {
        KeyframeButton.diamond(of: SuiteKeyframeFacing().face(for: presence))
    }
}

public struct KeyframeButton: View {
    private let property: String
    private let id: String?
    private let state: KeyState
    private let unavailableHelp: String?
    private let facing: any KeyframeFacing
    private let registers: Bool
    private let onToggle: @MainActor () -> Void
    private let onKey: @MainActor () -> Void
    @State private var hovering = false
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.suiteReduceMotion) private var reduceMotion

    /// `onToggle` turns animation on or off for `property`; `onKey` adds or
    /// removes the key at the playhead. `id` identifies the stopwatch, and
    /// `diamondID(id)` the diamond. `unavailableHelp` is why the pair can't act
    /// while the host disables it; both buttons show it as their tooltip.
    /// `facing` gives each state's symbols and spoken value; with `registers`
    /// both buttons list themselves in `suite.controls` under their ids.
    public init(
        _ property: String, id: String? = nil, state: KeyState, unavailableHelp: String? = nil,
        facing: any KeyframeFacing = SuiteKeyframeFacing(), registers: Bool = false,
        onToggle: @escaping @MainActor () -> Void, onKey: @escaping @MainActor () -> Void
    ) {
        self.property = property
        self.id = id
        self.state = state
        self.unavailableHelp = unavailableHelp
        self.facing = facing
        self.registers = registers
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

    /// The face's diamond as a symbol and its action's title; nil while the slot is empty.
    nonisolated public static func diamond(of face: KeyframeFace) -> (symbol: String, action: String)? {
        guard let symbol = face.diamondSymbol, let action = face.diamondAction else { return nil }
        return (symbol, action.title)
    }

    /// The stopwatch's and the diamond's `suite.controls` entries under `id`:
    /// while disabled each one's reason is its tooltip; no diamond entry while
    /// the slot is empty.
    nonisolated public static func entries(
        _ property: String, id: String, state: KeyState, enabled: Bool, unavailable: String? = nil
    ) -> (stopwatch: ControlEntry, diamond: ControlEntry?) {
        let tips = Self.help(property, state: state, unavailable: unavailable)
        let stopwatch = ControlEntry(id: id, enabled: enabled, reason: enabled ? nil : tips.stopwatch)
        let diamond = tips.diamond.map { ControlEntry(id: diamondID(id), enabled: enabled, reason: enabled ? nil : $0) }
        return (stopwatch, diamond)
    }

    public var body: some View {
        let help = Self.help(property, state: state, unavailable: unavailableHelp)
        let face = facing.face(for: state.presence)
        let entries = id.map {
            Self.entries(property, id: $0, state: state, enabled: isEnabled, unavailable: unavailableHelp)
        }
        return HStack(spacing: 0) {
            Button(action: onToggle) {
                Image(systemName: face.symbol)
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
            .accessibilityValue(face.spoken)
            .accessibilityIdentifier(id ?? face.symbol)
            .suiteControl(id: registers ? entries?.stopwatch.id : nil, enabled: isEnabled,
                          reason: entries?.stopwatch.reason, identifies: false)
            ZStack {
                if let diamond = Self.diamond(of: face) {
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
                    .suiteControl(id: registers ? entries?.diamond?.id : nil, enabled: isEnabled,
                                  reason: entries?.diamond?.reason, identifies: false)
                }
            }
            .frame(width: SuiteSize.keyframeButton, height: SuiteSize.keyframeButton)
        }
        .opacity(isEnabled ? 1 : SuiteColor.disabledOpacity)
        .animation(SuiteMotion.state(reduceMotion: reduceMotion), value: hovering)
        .animation(SuiteMotion.state(reduceMotion: reduceMotion), value: state)
    }

    /// The diamond's identifier beside the stopwatch identified `id`.
    nonisolated public static func diamondID(_ id: String) -> String { "\(id).diamond" }
}
