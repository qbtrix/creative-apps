// ColorKeyRules.swift (timeline-keys TK-1 stub, TK-5 body): the colour-track
// twin of `KeyRules`. A colour track is FlareCore's `[ColorKeyframe]`; its key
// button follows the same frame rules as a number track, a toggle at a keyed
// frame removes that key by its `RemovePolicy`, and a sample goes through
// FlareCore's colour easing (`Layer.sampledColor`). State and removal run
// through `KeyRules` on the track's frames; no colour maths lives here.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore

/// A colour key: FlareCore's `ColorKeyframe` (frame, sRGB value, easing to the next key).
public typealias ColorKeyframe = FlareCore.ColorKeyframe

/// Key state, toggle and sampling for one colour track.
public enum ColorKeyRules {
    /// The key button's state at `frame`, by `KeyRules.state`'s frame rules.
    public static func state(_ track: [ColorKeyframe], at frame: Int) -> KeyState {
        KeyRules.state(frames(of: track), at: frame)
    }

    /// Adds a key of `value` at `frame` in frame order, or removes the key
    /// there leaving the track by `leaving`. True when the track changed.
    public static func toggleKey(
        _ track: inout [ColorKeyframe], at frame: Int, value: FlareCore.Color, leaving: RemovePolicy
    ) -> Bool {
        if track.contains(where: { $0.frame == frame }) {
            var keys = frames(of: track)
            KeyRules.removeKeys(&keys, [frame], leaving: leaving)
            let kept = Set(keys.map(\.frame))
            track.removeAll { !kept.contains($0.frame) }
        } else {
            let index = track.firstIndex { $0.frame > frame } ?? track.endIndex
            track.insert(ColorKeyframe(frame: frame, value: value), at: index)
        }
        return true
    }

    /// The colour at `frame` through each key's easing, holding the ends; nil
    /// for an empty track (the property's static colour applies).
    public static func sample(_ track: [ColorKeyframe], at frame: Int) -> FlareCore.Color? {
        guard !track.isEmpty else { return nil }
        let fill = TrackTarget.fill(shape: 0)
        return FlareCore.Layer(id: "", name: "", colorTracks: [fill.key: track]).sampledColor(fill, at: Double(frame))
    }

    /// The track's frames as number keys, so `KeyRules`' frame rules apply.
    private static func frames(of track: [ColorKeyframe]) -> [Keyframe] {
        track.map { Keyframe(frame: $0.frame, value: 0) }
    }
}
