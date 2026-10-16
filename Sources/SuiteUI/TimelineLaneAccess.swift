// TimelineLaneAccess.swift: a TimelineLane's accessibility (TL-12). The lane
// is one element named for its track whose value reads its spans, then its
// keys ("Frames 20–50, 3 keyframes at 20, 30, 50"; "No keyframes"). Each key
// is a synthetic child ("Key at frame 24, eased") over its diamond, selected
// when picked, whose default action picks it alone (.replace) through the
// strip's TimelineKeyPicker. The children are built in the lane body, which a
// scrub never runs (lesson 153); the picker and the mapping reach it through
// the environment, set by TimelineStripKeys and equal across a scrub. The
// strings and the children are TimelineLaneSpeech, with no view.
import SwiftUI

struct TimelineLaneAccess<ID: Hashable & Sendable>: ViewModifier {
    let track: TimelineTrack<ID>
    @Environment(\.timelineKeyPicker) private var picker
    @Environment(\.timelineLaneMapping) private var mapping

    func body(content: Content) -> some View {
        let track = track
        let picker = picker
        let mapping = mapping
        let size = SuiteSize.timelineKeyframeHit
        return content
            .accessibilityElement()
            .accessibilityLabel(track.name)
            .accessibilityValue(TimelineLaneSpeech.value(of: track))
            .accessibilityChildren {
                ZStack(alignment: .topLeading) {
                    ForEach(TimelineLaneSpeech.children(of: track), id: \.frame) { child in
                        Rectangle()
                            .frame(width: size, height: size)
                            .position(
                                x: mapping.map { tickX($0, child.frame) } ?? 0,
                                y: SuiteSize.timelineLane / 2)
                            .accessibilityElement()
                            .accessibilityLabel(child.label)
                            .accessibilityAddTraits(child.picked ? .isSelected : [])
                            .accessibilityAction { TimelineLaneSpeech.activate(child.frame, on: track, picker: picker) }
                    }
                }
                .frame(maxWidth: .infinity, minHeight: SuiteSize.timelineLane, alignment: .topLeading)
            }
    }
}

/// One key's accessibility child: its frame, what it reads and whether it is picked.
struct TimelineKeyChild: Equatable, Sendable {
    let frame: Int
    let label: String
    let picked: Bool
}

/// What a lane and its keys say, with no view (TimelineAccessTests).
enum TimelineLaneSpeech {
    /// The lane's value: each span, then the keys in frame order.
    static func value<ID>(of track: TimelineTrack<ID>) -> String {
        let frames = track.keyframes.sorted()
        let keys: String
        switch frames.count {
        case 0: keys = "No keyframes"
        case 1: keys = "1 keyframe at \(frames.map(String.init).joined())"
        default: keys = "\(frames.count) keyframes at \(frames.map(String.init).joined(separator: ", "))"
        }
        let spans = track.spans.map { "Frames \($0.lowerBound)–\($0.upperBound)" }
        return (spans + [keys]).joined(separator: ", ")
    }

    /// A key's label: its frame and its shape.
    static func keyLabel(frame: Int, shape: TimelineKeyShape) -> String {
        "Key at frame \(frame), \(shape.rawValue)"
    }

    /// The track's key children in frame order, one per frame.
    static func children<ID>(of track: TimelineTrack<ID>) -> [TimelineKeyChild] {
        var seen = Set<Int>()
        return track.keys.sorted { $0.frame < $1.frame }.compactMap { key in
            guard seen.insert(key.frame).inserted else { return nil }
            return TimelineKeyChild(
                frame: key.frame, label: keyLabel(frame: key.frame, shape: key.shape),
                picked: track.pickedFrames.contains(key.frame))
        }
    }

    /// A key child's default action: it alone is picked.
    @MainActor static func activate<ID>(_ frame: Int, on track: TimelineTrack<ID>, picker: TimelineKeyPicker?) {
        picker?.pick(AnyHashable(track.id), frame)
    }
}

/// The strip's pick closure for a key child's default action. The strip keeps
/// one in @State and refreshes its closure, so the environment value a lane
/// reads stays the same object across a scrub.
@MainActor final class TimelineKeyPicker {
    private(set) var pick: @MainActor (AnyHashable, Int) -> Void = { _, _ in }

    /// Picks through `onPickKeyframe` with .replace from now on.
    func update<ID: Hashable & Sendable>(_ onPickKeyframe: @escaping @MainActor (ID, Int?, PickMode) -> Void) {
        pick = { id, frame in
            if let id = id.base as? ID { onPickKeyframe(id, frame, .replace) }
        }
    }
}

extension EnvironmentValues {
    /// The strip's key picker; nil outside a strip, where a key's action does nothing.
    var timelineKeyPicker: TimelineKeyPicker? {
        get { self[TimelineKeyPickerKey.self] }
        set { self[TimelineKeyPickerKey.self] = newValue }
    }

    /// The strip's mapping at its zoom, so a key child sits over its diamond.
    var timelineLaneMapping: FrameMapping? {
        get { self[TimelineLaneMappingKey.self] }
        set { self[TimelineLaneMappingKey.self] = newValue }
    }
}

private struct TimelineKeyPickerKey: EnvironmentKey {
    static let defaultValue: TimelineKeyPicker? = nil
}

private struct TimelineLaneMappingKey: EnvironmentKey {
    static let defaultValue: FrameMapping? = nil
}
