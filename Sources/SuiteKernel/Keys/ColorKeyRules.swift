// ColorKeyRules.swift (timeline-keys TK-1 stub, TK-5 body): the colour-track
// twin of `KeyRules`. A colour track is FlareCore's `[ColorKeyframe]`; its key
// button follows the same frame rules as a number track, a toggle at a keyed
// frame removes that key by its `RemovePolicy`, and a sample goes through
// FlareCore's colour easing. No colour or frame maths is re-derived here.
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
        .notAnimated
    }

    /// Adds a key of `value` at `frame` in frame order, or removes the key
    /// there leaving the track by `leaving`. True when the track changed.
    public static func toggleKey(
        _ track: inout [ColorKeyframe], at frame: Int, value: FlareCore.Color, leaving: RemovePolicy
    ) -> Bool {
        false
    }

    /// The colour at `frame` through each key's easing, holding the ends; nil
    /// for an empty track (the property's static colour applies).
    public static func sample(_ track: [ColorKeyframe], at frame: Int) -> FlareCore.Color? {
        nil
    }
}
