// FlarePlayback.swift: the playhead and the transport (docs/blueprints/flare.md, sections 1, 3.1 and 7.5, LM-7).
// `playClock` is the playhead's position in seconds from the timeline's first frame while playing; the display link
// (LA-2) calls `advance(elapsed:)` with the seconds since its last tick and the frame comes from
// `Timeline.playbackFrame`, so it never drifts from the clock. The timeline is the edited symbol's while editing in
// place (`timelineFrames`), played at the scene's rate. Nothing here touches the document, so scrubbing and
// playback are never undo steps (QB-F3).
import FlareCore

extension FlareWorkspace {
    /// The rate the timeline plays at: the selected scene's; a symbol has none of its own.
    public var playbackFPS: Int { selectedScene?.fps ?? 0 }

    /// The frames the playhead can stand on: the edited symbol's while editing in place, else the scene's.
    public var playbackRange: Range<Int> { 0..<timelineFrames }

    /// Whether play can start: an open timeline with at least one frame and a positive rate.
    public var canPlay: Bool { timelineFrames > 0 && playbackFPS > 0 }

    /// The frame readout under the stage, "12 / 48"; nil with no timeline. Journeys read the frame from its start.
    public var frameReadout: String? { frameReadoutParts.map { $0.current + $0.total } }

    /// The frame readout split for drawing: the current frame ("12") in primary text, the total (" / 48") in
    /// secondary (docs/design.md, Status pills and transport; #1859).
    public var frameReadoutParts: (current: String, total: String)? {
        canPlay ? ("\(currentFrame)", " / \(timelineFrames)") : nil
    }

    /// The frame readout's tooltip: frames count from 0, so the last of 48 is 47 (#1844).
    public var frameReadoutHelp: String? {
        guard canPlay else { return nil }
        return "Frame \(currentFrame) of \(timelineFrames). Frames count from 0, so the last frame is "
            + "\(timelineFrames - 1)."
    }

    /// The timecode under the stage, "00:12 / 02:00" (seconds and frames); nil with no timeline.
    public var timecode: String? { timecodeParts.map { $0.current + $0.total } }

    /// The timecode split for drawing: the current value ("00:12") in primary text, the total (" / 02:00") in
    /// secondary (#1859).
    public var timecodeParts: (current: String, total: String)? {
        let fps = playbackFPS
        guard canPlay else { return nil }
        func code(_ frame: Int) -> String {
            let (seconds, frames) = frame.quotientAndRemainder(dividingBy: fps)
            return "\(seconds < 10 ? "0" : "")\(seconds):\(frames < 10 ? "0" : "")\(frames)"
        }
        return (code(currentFrame), " / \(code(timelineFrames))")
    }

    /// The timecode's tooltip: it is seconds:frames, not minutes:seconds, at the scene's rate (#1844). At frame 47 of
    /// 48 at 24 fps: "Seconds:frames at 24 fps: 1 second and 23 frames of 2 seconds and 0 frames."
    public var timecodeHelp: String? {
        let fps = playbackFPS
        guard canPlay else { return nil }
        func spoken(_ frame: Int) -> String {
            let (seconds, frames) = frame.quotientAndRemainder(dividingBy: fps)
            return "\(seconds) second\(seconds == 1 ? "" : "s") and \(frames) frame\(frames == 1 ? "" : "s")"
        }
        return "Seconds:frames at \(fps) fps: \(spoken(currentFrame)) of \(spoken(timelineFrames))."
    }

    /// Moves a playhead past the timeline's end to its last frame (frame 0 with no frames), keeping a running play's
    /// clock on it (#615). Called after anything that can shorten the timeline: a scene switch or an edit. A running
    /// play whose rate changed from `fps` keeps its frame and plays on from there at the new rate (#640). One whose
    /// length changed from `frames` does too: a looping play's clock counts every pass, so it is rebased onto the
    /// frame, not left to wrap by the new length (#665).
    mutating func clampPlayhead(rateWas fps: Int? = nil, framesWas frames: Int? = nil) {
        let last = max(timelineFrames - 1, 0)
        let rateChanged = fps != nil && fps != playbackFPS
        let lengthChanged = frames != nil && frames != timelineFrames
        guard currentFrame > last || rateChanged || lengthChanged else { return }
        currentFrame = min(currentFrame, last)
        if isPlaying { playClock = canPlay ? Double(currentFrame) / Double(playbackFPS) : 0 }
    }

    /// Starts playing from the playhead. Without loop, playing from the last frame starts over from the first.
    public mutating func play() {
        guard canPlay else { return }
        let last = timelineFrames - 1
        if !loops, currentFrame >= last { currentFrame = 0 }
        currentFrame = min(max(currentFrame, 0), last)
        playClock = Double(currentFrame) / Double(playbackFPS)
        isPlaying = true
    }

    /// Stops playing; the playhead stays where it is.
    public mutating func pause() {
        isPlaying = false
    }

    /// Space and the round play button.
    public mutating func togglePlay() {
        if isPlaying { pause() } else { play() }
    }

    /// The transport's loop toggle; a running play keeps going under the new rule from where the playhead is. The
    /// clock is rebased onto the current pass, keeping the time into the frame, so a looping play past its first pass
    /// that turns Loop off plays on to the last frame instead of jumping there (#614). The rebased clock starts from
    /// the frame on screen: summed ticks can leave the clock a hair under a whole pass while the frame already shows
    /// the wrap to 0, so a time into the frame outside `[0, 1 / fps)` counts as none (#653).
    public mutating func setLoops(_ on: Bool) {
        loops = on
        guard isPlaying, canPlay else { return }
        let fps = Double(playbackFPS)
        let pass = Double(timelineFrames) / fps
        let start = Double(currentFrame) / fps
        let intoFrame = playClock.truncatingRemainder(dividingBy: pass) - start
        playClock = start + (intoFrame >= 0 && intoFrame < 1 / fps ? intoFrame : 0)
    }

    /// Moves the clock by `elapsed` seconds and the playhead with it. Looping wraps to the first frame; without loop
    /// playback stops on the last frame once that frame has had its time. Ignored while paused and for an elapsed
    /// time that is not a positive finite number.
    public mutating func advance(elapsed: Double) {
        guard isPlaying else { return }
        guard canPlay else { isPlaying = false; return }
        guard elapsed.isFinite, elapsed > 0 else { return }
        let fps = playbackFPS, frames = timelineFrames
        playClock += elapsed
        guard let frame = try? Timeline.playbackFrame(elapsed: playClock, fps: fps, durationFrames: frames, loop: loops)
        else { isPlaying = false; return }
        currentFrame = frame
        if !loops, playClock * Double(fps) >= Double(frames) { isPlaying = false }
    }

    /// Puts the playhead on `frame`, clamped to the timeline; a running play continues from there.
    public mutating func setCurrentFrame(_ frame: Int) {
        guard canPlay else { return }
        currentFrame = min(max(frame, 0), timelineFrames - 1)
        if isPlaying { playClock = Double(currentFrame) / Double(playbackFPS) }
    }

    /// The step buttons and the arrow keys: pauses, then moves `delta` frames, wrapping with loop on, else clamped.
    public mutating func stepFrame(by delta: Int) {
        guard canPlay else { return }
        pause()
        let frames = timelineFrames
        if loops {
            let wrapped = (currentFrame % frames) + delta % frames
            currentFrame = ((wrapped % frames) + frames) % frames
        } else {
            let (sum, overflow) = currentFrame.addingReportingOverflow(delta)
            setCurrentFrame(overflow ? (delta > 0 ? Int.max : Int.min) : sum)
        }
    }

    /// The transport's start button: the first frame.
    public mutating func goToStart() {
        setCurrentFrame(0)
    }

    /// The transport's end button: the last frame.
    public mutating func goToEnd() {
        setCurrentFrame(timelineFrames - 1)
    }
}
