// TimelineKeys.swift: the timeline's key rules, pure and Foundation only.
// SuiteKeyEditing is the live UC12 KeyEditing (Contracts/KeyEditing.swift):
// ← and → step along one track, a drag's points round to whole frames, and a
// move clamps the picked keys as a group so they keep their spacing (the Fake
// clamps each key on its own). TimelinePick is the pick rule a press on a key
// follows: Shift extends, Command toggles, else it replaces; a right press
// picks an unpicked key and leaves a picked one alone (B6). The lane's pointer
// (TL-11) and keys (TL-12) call these; no SwiftUI type appears here.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct SuiteKeyEditing: KeyEditing {
    public init() {}

    public func nextKey(after key: LaneKey, direction: Int, tracks: [String: [Int]]) -> LaneKey? {
        let frames = Set(tracks[key.track] ?? []).sorted()
        guard direction != 0, let index = frames.firstIndex(of: key.frame) else { return nil }
        let next = index + (direction > 0 ? 1 : -1)
        guard frames.indices.contains(next) else { return nil }
        return LaneKey(track: key.track, frame: frames[next])
    }

    public func frameDelta(points: Double, scale: TimelineScale) -> Int {
        guard scale.frameWidth > 0, scale.frameWidth.isFinite, points.isFinite else { return 0 }
        // Bounded before the Int conversion, which traps outside Int's range.
        return Int(min(max((points / scale.frameWidth).rounded(), -1_000_000_000), 1_000_000_000))
    }

    public func moved(_ keys: Set<LaneKey>, by delta: Int, lastFrame: Int) -> [LaneKey: Int] {
        let frames = keys.map(\.frame)
        guard let lowest = frames.min(), let highest = frames.max() else { return [:] }
        let last = max(lastFrame, 0)
        // The group's delta: its last key stops at lastFrame, its first at 0 (0 wins a group wider than the range).
        let shift = max(min(delta, last - highest), -lowest)
        return Dictionary(uniqueKeysWithValues: keys.map { ($0, $0.frame + shift) })
    }
}

/// The pick rule for a press on a key.
public enum TimelinePick {
    /// A left press on a key: Shift extends the pick, Command toggles the key, else the key replaces it.
    public static func mode(pressWith modifiers: KeyModifiers) -> PickMode {
        if modifiers.contains(.shift) { return .extend }
        if modifiers.contains(.command) { return .toggle }
        return .replace
    }

    /// A right press on a key: an unpicked key replaces the pick so the menu acts on it; a picked key changes nothing.
    public static func mode(rightPressOnPicked picked: Bool) -> PickMode? {
        return picked ? nil : .replace
    }
}
