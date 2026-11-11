// TimelineLaneAccess.swift: a TimelineLane's accessibility (TL-12). The lane
// is one element named for its track whose value reads its spans, then its
// keys ("Frames 20–50, 3 keyframes at 20, 30, 50"; "No keyframes"). Each key
// is a synthetic child ("Key at frame 24, eased") over its diamond, selected
// when picked, whose default action picks it alone (.replace) through the
// strip's TimelineKeyPicker. The children are built in the lane body, which a
// scrub never runs (lesson 153); the picker and the mapping reach it through
// the environment, set by TimelineStripKeys and equal across a scrub. The
// strings and the children are TimelineLaneSpeech, with no view. Only keys
// in the strip's visible x (timelineVisibleX), plus one key past each edge,
// get a child, and the value speaks the first 10 keys, so a 20,000 pt lane of
// 400 keys doesn't flood the tree (#1800). A child is the 16 pt token, narrowed
// to the gap to its nearest key (hitWidths), so keys a frame apart don't overlap. Identifiers are opt-in: with a
// timelineIdentifierPrefix P the lane is `P.lane.<id>` and each key child
// `P.key.<id>.<frame>`; with none nothing inside gets one. Halo sets
// `halo.timeline` and Flare `flare.timeline`.
import SwiftUI

struct TimelineLaneAccess<ID: Hashable & Sendable>: ViewModifier {
    let track: TimelineTrack<ID>
    @Environment(\.timelineKeyPicker) private var picker
    @Environment(\.timelineLaneMapping) private var mapping
    @Environment(\.timelineVisibleX) private var visibleX
    @Environment(\.timelineIdentifierPrefix) private var prefix

    func body(content: Content) -> some View {
        let track = track
        let picker = picker
        let mapping = mapping
        let prefix = prefix
        let children = TimelineLaneSpeech.children(of: track, visibleX: visibleX, mapping: mapping)
        let laneID = TimelineLaneSpeech.identifier(prefix, "lane", track.id)
        let widths = TimelineLaneSpeech.hitWidths(of: children, frameWidth: mapping?.frameWidth)
        return content
            .accessibilityElement()
            .accessibilityLabel(track.name)
            .accessibilityValue(TimelineLaneSpeech.value(of: track))
            .accessibilityIdentifier(laneID ?? "", isEnabled: laneID != nil)
            .accessibilityChildren {
                ZStack(alignment: .topLeading) {
                    ForEach(Array(zip(children, widths)), id: \.0.frame) { child, width in
                        let keyID = TimelineLaneSpeech.identifier(prefix, "key", track.id, frame: child.frame)
                        Rectangle()
                            .frame(width: width, height: SuiteSize.timelineKeyframeHit)
                            .position(
                                x: mapping.map { tickX($0, child.frame) } ?? 0,
                                y: SuiteSize.timelineLane / 2)
                            .accessibilityElement()
                            .accessibilityLabel(child.label)
                            .accessibilityAddTraits(child.picked ? .isSelected : [])
                            .accessibilityIdentifier(keyID ?? "", isEnabled: keyID != nil)
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
    /// How many keys a lane's value names before "and N more".
    static let spokenKeys = 10

    /// The lane's value: each span, then the first `spokenKeys` keys in frame order.
    static func value<ID>(of track: TimelineTrack<ID>) -> String {
        let frames = track.keyframes.sorted()
        let spoken = frames.prefix(spokenKeys).map(String.init).joined(separator: ", ")
        let more = frames.count > spokenKeys ? ", and \(frames.count - spokenKeys) more" : ""
        let keys: String
        switch frames.count {
        case 0: keys = "No keyframes"
        case 1: keys = "1 keyframe at \(spoken)"
        default: keys = "\(frames.count) keyframes at \(spoken)\(more)"
        }
        let spans = track.spans.map { "Frames \($0.lowerBound)–\($0.upperBound)" }
        return (spans + [keys]).joined(separator: ", ")
    }

    /// A key's label: its frame and its shape.
    static func keyLabel(frame: Int, shape: TimelineKeyShape) -> String {
        "Key at frame \(frame), \(shape.rawValue)"
    }

    /// The track's key children in frame order, one per frame: with a
    /// visible x range (mapping x) and a mapping, only those inside it plus
    /// one key past each edge; with either nil, every key.
    static func children<ID>(
        of track: TimelineTrack<ID>, visibleX: ClosedRange<Double>? = nil, mapping: FrameMapping? = nil
    ) -> [TimelineKeyChild] {
        var seen = Set<Int>()
        let all = track.keys.sorted { $0.frame < $1.frame }.compactMap { key -> TimelineKeyChild? in
            guard seen.insert(key.frame).inserted else { return nil }
            return TimelineKeyChild(
                frame: key.frame, label: keyLabel(frame: key.frame, shape: key.shape),
                picked: track.pickedFrames.contains(key.frame))
        }
        guard let visibleX, let mapping else { return all }
        let xs = all.map { mapping.x(forFrame: $0.frame) }
        let first = (xs.firstIndex { $0 >= visibleX.lowerBound } ?? xs.count) - 1
        let last = (xs.lastIndex { $0 <= visibleX.upperBound } ?? -1) + 1
        let low = max(first, 0)
        let high = min(last, all.count - 1)
        guard low <= high else { return [] }
        return Array(all[low...high])
    }

    /// Each child's hit width: the 16 pt key token, narrowed to the gap to its
    /// nearest neighbour, so keys a frame apart at a tight zoom never cover
    /// each other (the app audit's overlap check) and each covers what a click
    /// picks (the nearest key). With no frame width, the full token.
    static func hitWidths(of children: [TimelineKeyChild], frameWidth: Double?) -> [CGFloat] {
        let hit = SuiteSize.timelineKeyframeHit
        guard let frameWidth, frameWidth > 0, frameWidth.isFinite else { return children.map { _ in hit } }
        return children.indices.map { i in
            var width = hit
            for j in [i - 1, i + 1] where children.indices.contains(j) {
                width = min(width, CGFloat(Double(abs(children[j].frame - children[i].frame)) * frameWidth))
            }
            return width
        }
    }

    /// A strip part's identifier under `prefix` (`P.lane.<id>`, `P.key.<id>.<frame>`,
    /// `P.name.<id>`); nil with no prefix, so a host's own identifier stands alone.
    static func identifier<ID>(_ prefix: String?, _ part: String, _ id: ID, frame: Int? = nil) -> String? {
        guard let prefix else { return nil }
        return "\(prefix).\(part).\(id)" + (frame.map { ".\($0)" } ?? "")
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

    /// The stretch of lanes the strip shows, in mapping x; nil in a snapshot
    /// or before the scroll view reports, when every key gets a child.
    var timelineVisibleX: ClosedRange<Double>? {
        get { self[TimelineVisibleXKey.self] }
        set { self[TimelineVisibleXKey.self] = newValue }
    }

    /// The prefix a host sets for the strip's inner identifiers; nil puts none.
    public var timelineIdentifierPrefix: String? {
        get { self[TimelineIdentifierPrefixKey.self] }
        set { self[TimelineIdentifierPrefixKey.self] = newValue }
    }
}

private struct TimelineKeyPickerKey: EnvironmentKey {
    static let defaultValue: TimelineKeyPicker? = nil
}

private struct TimelineLaneMappingKey: EnvironmentKey {
    static let defaultValue: FrameMapping? = nil
}

private struct TimelineVisibleXKey: EnvironmentKey {
    static let defaultValue: ClosedRange<Double>? = nil
}

private struct TimelineIdentifierPrefixKey: EnvironmentKey {
    static let defaultValue: String? = nil
}
