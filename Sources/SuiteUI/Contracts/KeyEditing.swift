// KeyEditing.swift: UC12, stepping, dragging and moving timeline keys, and
// FakeKeyEditing, which clamps each key on its own on purpose (the live rule
// clamps the group). Foundation only; verbatim from blueprint section 5.2.
// The live rule is TL-10's SuiteKeyEditing.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct LaneKey: Hashable, Sendable {
    public var track: String
    public var frame: Int
    public init(track: String, frame: Int) { self.track = track; self.frame = frame }
}

public protocol KeyEditing: Sendable {
    /// The key the selection moves to with ← or → (`direction` −1 or +1): along the same track, nil at its ends (#63).
    func nextKey(after key: LaneKey, direction: Int, tracks: [String: [Int]]) -> LaneKey?
    /// Whole frames a drag of `points` moves keys by.
    func frameDelta(points: Double, scale: TimelineScale) -> Int
    /// Old key to new frame for moving `keys` by `delta`, clamped as a group so none leaves 0...lastFrame.
    func moved(_ keys: Set<LaneKey>, by delta: Int, lastFrame: Int) -> [LaneKey: Int]
}

/// Moves each key on its own, clamping each (the live rule clamps the group).
public struct FakeKeyEditing: KeyEditing {
    public init() {}
    public func nextKey(after key: LaneKey, direction: Int, tracks: [String: [Int]]) -> LaneKey? {
        let frames = (tracks[key.track] ?? []).sorted()
        guard let i = frames.firstIndex(of: key.frame), frames.indices.contains(i + direction) else { return nil }
        return LaneKey(track: key.track, frame: frames[i + direction])
    }
    public func frameDelta(points: Double, scale: TimelineScale) -> Int {
        scale.frameWidth > 0 && points.isFinite ? Int((points / scale.frameWidth).rounded()) : 0
    }
    public func moved(_ keys: Set<LaneKey>, by delta: Int, lastFrame: Int) -> [LaneKey: Int] {
        Dictionary(uniqueKeysWithValues: keys.map { ($0, min(max($0.frame + delta, 0), max(lastFrame, 0))) })
    }
}
