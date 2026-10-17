// HaloPlayback.swift: the transport's workspace methods (#37, VP-3): play,
// pause, toggle, Loop, the display link's tick, frame steps and the start and
// end jumps, plus the labels the transport reads. `services.clock` does the
// frame math; a tick re-anchors when the playhead moved since the last tick
// (a scrub while playing) and on each loop wrap, so turning Loop off mid-play
// ends the current pass. Never calls `edit`: playback is not an undo step
// (QB-F3). Writes only `playback` and the playhead, through `scrub(to:)`.
// `tickChanges(now:)` says whether a tick would change anything, so the
// window ticks only then and a refresh between frames writes nothing.
// Linux-safe: no UI imports.

extension HaloProject {
    /// Starts playing the selected composition from the playhead at `now`
    /// seconds on the app's clock. With Loop off on the last frame it starts
    /// from 0. Does nothing without a composition or a working clock.
    public mutating func play(at now: Double) {
        guard let comp = selectedComposition, services.clock.unavailableHelp == nil else { return }
        if !playback.loops && comp.playheadFrame == comp.lastFrame { scrub(to: 0) }
        let frame = selectedComposition?.playheadFrame ?? 0
        playback = HaloPlaybackState(
            playing: true, loops: playback.loops, startFrame: frame, startTime: now, lastFrame: frame)
    }

    /// Stops playing; the playhead stays where it is.
    public mutating func pause() {
        playback.playing = false
    }

    /// Space: pauses while playing, otherwise plays from the playhead at `now`.
    public mutating func togglePlay(at now: Double) {
        if playback.playing { pause() } else { play(at: now) }
    }

    /// Turns Loop on or off; a pass already playing ends at the last frame.
    public mutating func setLoops(_ loops: Bool) {
        playback.loops = loops
    }

    /// Moves the playhead to the frame `now` seconds shows. False once
    /// stopped: not playing, no composition, or play-once reached the end.
    /// A `now` that is not finite keeps the frame and keeps playing.
    @discardableResult
    public mutating func tick(now: Double) -> Bool {
        guard playback.playing, let comp = selectedComposition else {
            playback.playing = false
            return false
        }
        guard now.isFinite else { return true }
        var state = playback
        if comp.playheadFrame != state.lastFrame || !state.startTime.isFinite {
            state.startFrame = comp.playheadFrame
            state.startTime = now
        }
        let n = comp.durationFrames
        let fps = comp.framesPerSecond
        if state.loops, n > 0, fps > 0 {
            let full = Double(n) / Double(fps)
            let pass = Double(n - state.startFrame) / Double(fps)
            if now - state.startTime >= pass {
                state.startTime += pass
                state.startFrame = 0
                let wraps = ((now - state.startTime) / full).rounded(.down)
                if wraps > 0 { state.startTime += wraps * full }
            }
        }
        let t = services.clock.tick(
            startFrame: state.startFrame, elapsed: now - state.startTime, framesPerSecond: fps,
            durationFrames: n, loops: state.loops)
        scrub(to: t.frame)
        state.lastFrame = selectedComposition?.playheadFrame ?? t.frame
        if t.ended { state.playing = false }
        playback = state
        return state.playing
    }

    /// Whether `tick(now:)` at `now` would change anything: the frame, the
    /// anchor a scrub while playing moves (the frame can stay put), or the
    /// end of a play-once pass. Ticks on a copy and compares, so a refresh
    /// between two frames lets the window skip its write (#1296).
    public func tickChanges(now: Double) -> Bool {
        var next = self
        next.tick(now: now)
        return next != self
    }

    /// ← and →: pauses, then moves the playhead `frames` frames, clamped.
    public mutating func stepFrame(by frames: Int) {
        pause()
        guard let comp = selectedComposition else { return }
        // Bounded first, so Int.max or Int.min can't overflow the sum.
        let step = min(max(frames, -comp.lastFrame), comp.lastFrame)
        scrub(to: comp.playheadFrame + step)
    }

    /// Home: pauses and moves the playhead to frame 0.
    public mutating func goToStart() {
        pause()
        scrub(to: 0)
    }

    /// End: pauses and moves the playhead to the last frame.
    public mutating func goToEnd() {
        pause()
        scrub(to: selectedComposition?.lastFrame ?? 0)
    }

    /// The play control's value: "Playing" or "Paused".
    public var playLabel: String { playback.playing ? "Playing" : "Paused" }

    /// The Loop control's value: "On" or "Off".
    public var loopLabel: String { playback.loops ? "On" : "Off" }
}
