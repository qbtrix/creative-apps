// TimelineStrip+Keys.swift: TimelineStrip's focus-scoped keys (TL-12). The
// strip is focusable (TL-17's `.focusable` in TimelineStrip); this modifier,
// mounted right after it, draws the 2 pt accent ring 1 pt outside while the
// strip has focus (as ScrubField) and steps the pick with ← and →:
// SuiteKeyEditing.nextKey from the picked key (on the selected track if it has
// one, else the first picked track; the last picked frame going right, the
// first going left) -> onPickKeyframe(.replace); with no pick, the first key
// of the selected track; nothing past either end. It also hands the lanes the
// key picker and mapping their accessibility children use (TimelineLaneAccess).
// A press on a lane takes the strip's focus (TimelineFocusClaim, which the
// lanes' input calls), as a canvas press does, so ⌘+ works right after a
// click (#1813). Zoom keys (⌘+, ⌘−, ⌘0) are not here; TL-17 has its own handler.
import SwiftUI

struct TimelineStripKeys<ID: Hashable & Sendable>: ViewModifier {
    let tracks: [TimelineTrack<ID>]
    let mapping: FrameMapping
    let onPickKeyframe: @MainActor (ID, Int?, PickMode) -> Void
    @State private var picker = TimelineKeyPicker()
    @State private var focusClaim = TimelineFocusClaim()
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        picker.update(onPickKeyframe)
        let focus = $isFocused
        focusClaim.claim = { if !focus.wrappedValue { focus.wrappedValue = true } }
        return content
            .focused($isFocused)
            .focusEffectDisabled()
            .overlay {
                if isFocused {
                    let out = SuiteSize.focusRingGap + SuiteSize.focusRing / 2
                    Rectangle()
                        .stroke(SuiteColor.accent, lineWidth: SuiteSize.focusRing)
                        .padding(-out)
                        .allowsHitTesting(false)
                }
            }
            .onKeyPress(keys: [.leftArrow, .rightArrow]) { press in
                guard press.modifiers.isDisjoint(with: [.command, .option, .control]) else { return .ignored }
                switch TimelineArrowStep.step(for: press.key, tracks: tracks) {
                case .ignored: return .ignored
                case .atEnd: return .handled
                case .pick(let id, let frame):
                    onPickKeyframe(id, frame, .replace)
                    return .handled
                }
            }
            .environment(\.timelineKeyPicker, picker)
            .environment(\.timelineFocusClaim, focusClaim)
            .environment(\.timelineLaneMapping, mapping)
    }
}

/// Gives the strip focus from a lane press. One object in the strip's @State,
/// its closure refreshed, so the environment value lanes read never changes.
@MainActor final class TimelineFocusClaim {
    var claim: @MainActor () -> Void = {}
}

extension EnvironmentValues {
    /// The strip's focus claim; nil outside a strip. A plain key, as TimelineLaneAccess's.
    var timelineFocusClaim: TimelineFocusClaim? {
        get { self[TimelineFocusClaimKey.self] }
        set { self[TimelineFocusClaimKey.self] = newValue }
    }
}

private struct TimelineFocusClaimKey: EnvironmentKey {
    static let defaultValue: TimelineFocusClaim? = nil
}

/// What ← and → do to the pick, with no view (TimelineAccessTests).
enum TimelineArrowStep {
    /// The step direction of an arrow: → is +1, ← is -1, else nil.
    static func direction(_ key: KeyEquivalent) -> Int? {
        if key == .rightArrow { return 1 }
        if key == .leftArrow { return -1 }
        return nil
    }

    /// What an arrow does on `tracks`.
    static func step<ID: Hashable & Sendable>(
        for key: KeyEquivalent, tracks: [TimelineTrack<ID>]
    ) -> TimelineArrowResult<ID> {
        guard let direction = direction(key) else { return .ignored }
        let anchorTrack = tracks.first { $0.isSelected && !$0.pickedFrames.isEmpty }
            ?? tracks.first { !$0.pickedFrames.isEmpty }
        guard let track = anchorTrack else {
            // No pick: the first key of the selected track.
            guard let selected = tracks.first(where: \.isSelected) else { return .ignored }
            return selected.keyframes.min().map { TimelineArrowResult.pick(selected.id, $0) } ?? .atEnd
        }
        let frames = track.keyframes
        let picked = track.pickedFrames.filter(frames.contains)
        guard let from = direction > 0 ? picked.max() : picked.min() else { return .atEnd }
        let next = SuiteKeyEditing().nextKey(
            after: LaneKey(track: "lane", frame: from), direction: direction, tracks: ["lane": frames])
        return next.map { TimelineArrowResult.pick(track.id, $0.frame) } ?? .atEnd
    }
}

/// An arrow's effect: not taken, taken with nothing past the end, or a key picked.
enum TimelineArrowResult<ID: Hashable & Sendable>: Equatable {
    case ignored
    case atEnd
    case pick(ID, Int)
}
