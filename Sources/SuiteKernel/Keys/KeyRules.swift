// KeyRules.swift (EK-3 stub, EK-16 body): the shared key rules over sorted
// tracks. Never traps: a frame sum that would overflow refuses or saturates.
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
    /// The keyframe button's state for `track` at `frame`: fewer than two keys
    /// is `.notAnimated`, a key at `frame` is `.keyedHere`, else `.animated`.
    public static func state(_ track: [Keyframe], at frame: Int) -> KeyState {
        guard track.count >= 2 else { return .notAnimated }
        return track.contains { $0.frame == frame } ? .keyedHere : .animated
    }

    /// Adds a key of `value` at `frame`, or removes the one there by `leaving`;
    /// true when the track changed.
    public static func toggleKey(_ track: inout [Keyframe], at frame: Int, value: Double, leaving: RemovePolicy) -> Bool {
        if track.contains(where: { $0.frame == frame }) {
            removeKeys(&track, [frame], leaving: leaving)
        } else {
            let index = track.firstIndex { $0.frame > frame } ?? track.endIndex
            track.insert(Keyframe(frame: frame, value: value), at: index)
        }
        return true
    }

    /// Animates a static property (keys at `frame` and `lastFrame` holding
    /// `value`) or makes an animated one static; true when it changed. A static
    /// property can't animate when `frame` and `lastFrame` are the same.
    public static func toggleAnimated(_ track: inout [Keyframe], at frame: Int, lastFrame: Int, value: Double) -> Bool {
        if track.count >= 2 {
            track = []
            return true
        }
        guard frame != lastFrame else { return false }
        track = [Keyframe(frame: min(frame, lastFrame), value: value), Keyframe(frame: max(frame, lastFrame), value: value)]
        return true
    }

    /// Moves the keys at `frames` on every track by `delta`, all or nothing:
    /// throws when any would leave `range` or land on a key that stays.
    public static func moveKeys(
        _ tracks: inout [String: [Keyframe]], _ frames: Set<Int>, by delta: Int, clampedTo range: ClosedRange<Int>
    ) throws(KeyRefusal) {
        guard delta != 0 else { return }
        for name in tracks.keys.sorted() {
            let track = tracks[name] ?? []
            let staying = Set(track.lazy.filter { !frames.contains($0.frame) }.map(\.frame))
            for key in track where frames.contains(key.frame) {
                let (sum, overflow) = key.frame.addingReportingOverflow(delta)
                let to = overflow ? (delta > 0 ? Int.max : Int.min) : sum
                guard range.contains(to) else { throw .pastRange(frame: to) }
                guard !staying.contains(to) else { throw .collides(frame: to) }
            }
        }
        for name in tracks.keys {
            guard var track = tracks[name] else { continue }
            for i in track.indices where frames.contains(track[i].frame) {
                track[i].frame = min(max(track[i].frame &+ delta, range.lowerBound), range.upperBound)
            }
            tracks[name] = inFrameOrder(track)
        }
    }

    /// Removes the keys at `frames`, then applies `leaving` to what is left.
    public static func removeKeys(_ track: inout [Keyframe], _ frames: Set<Int>, leaving: RemovePolicy) {
        track.removeAll { frames.contains($0.frame) }
        if leaving == .propertyGoesStatic, track.count < 2 { track = [] }
    }

    /// Inserts `count` frames after `frame`: later keys move later by `count`;
    /// a key at `frame` stays.
    public static func insertFrames(_ track: inout [Keyframe], _ count: Int, at frame: Int) {
        guard count > 0 else { return }
        for i in track.indices where track[i].frame > frame {
            let (sum, overflow) = track[i].frame.addingReportingOverflow(count)
            track[i].frame = overflow ? Int.max : sum
        }
    }

    /// Removes `count` frames from `frame` on: keys inside go, later keys move
    /// earlier by `count`.
    public static func removeFrames(_ track: inout [Keyframe], _ count: Int, at frame: Int) {
        guard count > 0 else { return }
        let (sum, overflow) = frame.addingReportingOverflow(count)
        let end = overflow ? Int.max : sum
        track.removeAll { $0.frame >= frame && $0.frame < end }
        for i in track.indices where track[i].frame >= end { track[i].frame -= count }
    }

    /// `track` sorted by frame, keeping the order of keys on the same frame.
    private static func inFrameOrder(_ track: [Keyframe]) -> [Keyframe] {
        track.enumerated().sorted { ($0.element.frame, $0.offset) < ($1.element.frame, $1.offset) }.map(\.element)
    }
}
