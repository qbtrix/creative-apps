// Fakes/FakePlaybackClock.swift: a small, predictable PlaybackClock (#37),
// so the transport runs before the live type lands. It rounds frame edges
// with the same 1e-9 as FlareCore's playbackFrame, so fake and live agree.
// Linux-safe; never used by `.live`.

public struct FakePlaybackClock: PlaybackClock {
    public init() {}
    public func tick(
        startFrame: Int, elapsed: Double, framesPerSecond: Int, durationFrames: Int, loops: Bool
    ) -> HaloPlaybackTick {
        guard durationFrames > 0, framesPerSecond > 0, elapsed.isFinite, elapsed > 0 else {
            return HaloPlaybackTick(frame: max(0, min(startFrame, durationFrames - 1)), ended: false)
        }
        let ahead = Int(min((elapsed * Double(framesPerSecond) + 1e-9).rounded(.down), 1e9))
        let raw = max(0, startFrame) + ahead
        if loops { return HaloPlaybackTick(frame: raw % durationFrames, ended: false) }
        return raw >= durationFrames - 1
            ? HaloPlaybackTick(frame: durationFrames - 1, ended: true) : HaloPlaybackTick(frame: raw, ended: false)
    }
}
