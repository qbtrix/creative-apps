// Keys.swift (EK-3 stub, EK-15 body): the key and easing words every timeline shares, over
// FlareCore's `Keyframe` and `Easing`. Stubs return fakes and never trap.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore

/// FlareCore's keyframe (frame, value, easing to the next key), under its kernel name.
public typealias Keyframe = FlareCore.Keyframe

/// FlareCore's easing (linear, cubic Bézier or hold), under its kernel name.
public typealias Easing = FlareCore.Easing

/// Which keys a row or a pick means: one property's track, or `all` of a layer's tracks.
public enum Track<Property: Hashable & Codable & Sendable>: Hashable, Codable, Sendable { case property(Property), all }

/// One key: the layer it is on, its track and its frame.
public struct KeyRef<Property: Hashable & Codable & Sendable>: Hashable, Codable, Sendable {
    /// The layer's id, the track the key is on and the key's frame.
    public var layerID: String, track: Track<Property>, frame: Int

    /// Names the key on `layerID`'s `track` at `frame`.
    public init(layerID: String, track: Track<Property>, frame: Int) {
        self.layerID = layerID; self.track = track; self.frame = frame
    }
}

/// What the keyframe button shows at the playhead: fewer than two keys
/// (`notAnimated`), animated with no key here, or a key at exactly this frame.
public enum KeyState: Sendable, Equatable { case notAnimated, animated, keyedHere }

/// The span from one key to the next, and the easing it plays with.
public struct Segment<Property: Hashable & Codable & Sendable>: Hashable, Sendable {
    /// The key the segment starts at, the next key's frame and the easing between.
    public var key: KeyRef<Property>, endFrame: Int, easing: Easing

    /// A segment from `key` to `endFrame` played with `easing`.
    public init(key: KeyRef<Property>, endFrame: Int, easing: Easing) {
        self.key = key; self.endFrame = endFrame; self.easing = easing
    }
}

/// The one list of easing presets every easing menu offers, in menu order;
/// `hold` keeps the value until the next key, then jumps.
public enum EasePreset: String, CaseIterable, Sendable {
    case linear, ease, easeIn, easeOut, easeInOut, hold

    /// The FlareCore easing the preset sets. Stub: `.linear` until EK-15.
    public var easing: Easing { .linear }

    /// The preset's menu title. Stub: the raw value until EK-15.
    public var title: String { rawValue }
}

/// The one handle math for an easing curve editor: the two Bézier handles in
/// the unit square, a handle dragged to a point, and points along the curve.
public enum EaseCurve {
    /// The two control points of a cubic Bézier easing; nil for linear and
    /// hold, which have no handles. Stub: nil until EK-15.
    public static func handles(of e: Easing) -> [Point]? { nil }

    /// `e` with handle `handle` (0 or 1) moved to `p`, x clamped to 0...1.
    /// Stub: `e` unchanged until EK-15.
    public static func moving(_ handle: Int, to p: Point, in e: Easing) -> Easing { e }

    /// `count` points along the curve from (0, 0) to (1, 1); a count of 1
    /// gives one point and counts are capped at 4096. Stub: none until EK-15.
    public static func samples(of e: Easing, count: Int) -> [Point] { [] }
}

/// What removing keys leaves: a single remaining key stays as the one value
/// (`singleStays`), or with one key or none left the track empties (`propertyGoesStatic`).
public enum RemovePolicy: Sendable { case singleStays, propertyGoesStatic }
