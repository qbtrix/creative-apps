// TimelineStrip+Keys.swift: TimelineStrip's focus-scoped keys (TL-12). The
// strip is focusable (TL-17's `.focusable` in TimelineStrip); this modifier,
// mounted right after it, draws the 2 pt accent ring 1 pt outside while the
// strip has focus (as ScrubField) and steps the pick with ← and →:
// SuiteKeyEditing.nextKey from the picked key (on the selected track if it has
// one, else the first picked track; the last picked frame going right, the
// first going left) -> onPickKeyframe(.replace); with no pick, the first key
// of the selected track; nothing past either end. It also hands the lanes the
// key picker and mapping their accessibility children use (TimelineLaneAccess).
// Zoom keys (⌘+, ⌘−, ⌘0) are not here; TL-17 has its own handler.
import SwiftUI

struct TimelineStripKeys<ID: Hashable & Sendable>: ViewModifier {
    let tracks: [TimelineTrack<ID>]
    let mapping: FrameMapping
    let onPickKeyframe: @MainActor (ID, Int?, PickMode) -> Void
    @State private var picker = TimelineKeyPicker()
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        picker.update(onPickKeyframe)
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
            .environment(\.timelineLaneMapping, mapping)
    }
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
