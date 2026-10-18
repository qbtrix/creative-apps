// KeyRules.swift (EK-3 stub, EK-16 body): the shared key rules. Stubs change nothing, never trap.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Why `KeyRules.moveKeys` refused (no key moved): a key would leave the
/// range (`pastRange`) or land on a key that stays (`collides`), at that frame.
public enum KeyRefusal: Error, Equatable, Sendable { case pastRange(frame: Int), collides(frame: Int) }

/// The key rules over sorted `[Keyframe]` tracks.
public enum KeyRules {
    /// The keyframe button's state for `track` at `frame`. Stub: `.notAnimated` until EK-16.
    public static func state(_ track: [Keyframe], at frame: Int) -> KeyState { .notAnimated }

    /// Adds a key of `value` at `frame`, or removes the one there by `leaving`;
    /// true when the track changed. Stub: false until EK-16.
    public static func toggleKey(_ track: inout [Keyframe], at frame: Int, value: Double, leaving: RemovePolicy) -> Bool {
        false
    }

    /// Animates a static property (keys at `frame` and `lastFrame` holding
    /// `value`) or makes an animated one static; true when it changed. Stub: false.
    public static func toggleAnimated(_ track: inout [Keyframe], at frame: Int, lastFrame: Int, value: Double) -> Bool {
        false
    }

    /// Moves the keys at `frames` on every track by `delta`, all or nothing:
    /// throws when any would leave `range` or land on a key that stays. Stub: no-op.
    public static func moveKeys(
        _ tracks: inout [String: [Keyframe]], _ frames: Set<Int>, by delta: Int, clampedTo range: ClosedRange<Int>
    ) throws(KeyRefusal) {}

    /// Removes the keys at `frames`, then applies `leaving` to what is left. Stub: no-op.
    public static func removeKeys(_ track: inout [Keyframe], _ frames: Set<Int>, leaving: RemovePolicy) {}

    /// Inserts `count` frames after `frame`: later keys move later by `count`. Stub: no-op.
    public static func insertFrames(_ track: inout [Keyframe], _ count: Int, at frame: Int) {}

    /// Removes `count` frames from `frame` on: keys inside go, later keys move
    /// earlier by `count`. Stub: no-op.
    public static func removeFrames(_ track: inout [Keyframe], _ count: Int, at frame: Int) {}
}
