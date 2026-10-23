// Keys.swift (EK-3 stub, EK-15 body): the key and easing words every timeline shares, over
// FlareCore's `Keyframe` and `Easing`: the six easing presets and the one handle and
// sample math of a curve editor. Every function is total and never traps.
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

    /// The FlareCore easing the preset sets.
    public var easing: Easing {
        switch self {
        case .linear: .linear
        case .ease: .ease
        case .easeIn: .easeIn
        case .easeOut: .easeOut
        case .easeInOut: .easeInOut
        case .hold: .hold
        }
    }

    /// The preset's menu title, in words.
    public var title: String {
        switch self {
        case .linear: "Linear"
        case .ease: "Ease"
        case .easeIn: "Ease In"
        case .easeOut: "Ease Out"
        case .easeInOut: "Ease In-Out"
        case .hold: "Hold"
        }
    }
}

/// The one handle math for an easing curve editor: the two Bézier handles in
/// the unit square, a handle dragged to a point, and points along the curve.
public enum EaseCurve {
    /// The most points `samples(of:count:)` returns.
    public static let maxSamples = 4096

    /// The two control points of a cubic Bézier easing; nil for linear and
    /// hold, which have no handles.
    public static func handles(of e: Easing) -> [Point]? {
        guard case let .cubicBezier(x1, y1, x2, y2) = e else { return nil }
        return [Point(x: x1, y: y1), Point(x: x2, y: y2)]
    }

    /// `e` with handle `handle` (0 or 1) moved to `p`, x clamped to 0...1 and
    /// y left free (overshoot). Linear and hold become a cubic Bézier whose
    /// handles start at (0, 0) and (1, 1). Any other handle or a non-finite
    /// point leaves `e` unchanged.
    public static func moving(_ handle: Int, to p: Point, in e: Easing) -> Easing {
        guard p.x.isFinite, p.y.isFinite else { return e }
        var points = handles(of: e) ?? [Point(x: 0, y: 0), Point(x: 1, y: 1)]
        guard points.count == 2, points.indices.contains(handle) else { return e }
        points[handle] = Point(x: min(max(p.x, 0), 1), y: p.y)
        let first = points[0], second = points[1]
        return .cubicBezier(x1: first.x, y1: first.y, x2: second.x, y2: second.y)
    }

    /// `count` points (x, eased y) evenly spaced from (0, 0) to (1, 1); a count
    /// of 1 gives (0, 0) alone, below 1 none, and counts are capped at 4096.
    public static func samples(of e: Easing, count: Int) -> [Point] {
        let n = min(count, maxSamples)
        guard n > 1 else { return n == 1 ? [Point(x: 0, y: e.value(at: 0))] : [] }
        let last = Double(n - 1)
        return (0..<n).map { i in
            let x = Double(i) / last
            return Point(x: x, y: e.value(at: x))
        }
    }
}

/// What removing keys leaves: a single remaining key stays as the one value
/// (`singleStays`), or with one key or none left the track empties (`propertyGoesStatic`).
public enum RemovePolicy: Sendable { case singleStays, propertyGoesStatic }
