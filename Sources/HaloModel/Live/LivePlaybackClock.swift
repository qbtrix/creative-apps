// Live/LivePlaybackClock.swift: the W0 stub of PlaybackClock. Every tick
// stays on the start frame and ends play; the playback feature (#37) replaces
// this file whole with the live type. Linux-safe.

public struct LivePlaybackClock: PlaybackClock {
    public init() {}
    public var unavailableHelp: String? { "Playback arrives with #37." }
    public func tick(
        startFrame: Int, elapsed: Double, framesPerSecond: Int, durationFrames: Int, loops: Bool
    ) -> HaloPlaybackTick {
        HaloPlaybackTick(frame: max(0, startFrame), ended: true)
    }
}
