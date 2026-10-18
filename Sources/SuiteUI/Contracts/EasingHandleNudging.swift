// EasingHandleNudging.swift: UC15b (SJ20), arrow nudges of the easing curve's
// two Bezier handles, and FakeEasingHandleNudging, which leaves x unclamped on
// purpose. Foundation only; verbatim from blueprint section 5.2.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The easing curve's two Bezier handles: x stays in 0...1, y may overshoot (no bound), not sorted.
public protocol EasingHandleNudging: Sendable {
    /// One arrow press on the focused handle: 0.01, ⇧ 0.1; x clamped to 0...1.
    func nudged(_ handle: PlanePoint, dx: Int, dy: Int, coarse: Bool) -> PlanePoint
    /// What VoiceOver and the gallery log say for a handle ("0.42, 1.10").
    func describe(_ handle: PlanePoint) -> String
}

/// Does not clamp x.
public struct FakeEasingHandleNudging: EasingHandleNudging {
    public init() {}
    public func nudged(_ handle: PlanePoint, dx: Int, dy: Int, coarse: Bool) -> PlanePoint {
        let s = coarse ? 0.1 : 0.01
        return PlanePoint(x: handle.x + Double(dx) * s, y: handle.y + Double(dy) * s)
    }
    public func describe(_ handle: PlanePoint) -> String { "\(handle.x), \(handle.y)" }
}
