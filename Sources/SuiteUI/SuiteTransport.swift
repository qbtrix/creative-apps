// SuiteTransport.swift: the transport capsule's live rule (UC13), Flare's
// semantics as one value TransportCapsule reads. Something can play when there
// is at least one frame and a positive rate; otherwise every move returns the
// state unchanged and the face carries the reason. A step pauses, then wraps
// while looping and clamps to the first or last frame otherwise; any `Int`
// step, `Int.max` included, never overflows. The timecode is seconds:frames
// ("01:12 / 02:00") with its spoken tooltip, and "--:-- / --:--" when nothing
// can play, so no rate of 0 is ever divided by. The state owners stay
// FlarePlayback and HaloPlayback; this is the face rule.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct SuiteTransport: TransportStepping {
    public init() {}

    /// Why nothing can play, or nil when something can.
    private func reason(_ s: TransportState) -> String? {
        if s.frameCount <= 0 { return "Nothing to play." }
        if s.fps <= 0 { return "No frame rate to play at." }
        return nil
    }

    /// `frame` inside 0...frameCount - 1; frameCount is positive here.
    private func clamped(_ frame: Int, _ s: TransportState) -> Int { min(max(frame, 0), s.frameCount - 1) }

    public func stepped(_ state: TransportState, by frames: Int) -> TransportState {
        guard reason(state) == nil else { return state }
        var next = state
        next.isPlaying = false
        let count = state.frameCount
        if state.loops {
            // Each remainder lies in (-count, count), so their sum can't overflow.
            let wrapped = state.frame % count + frames % count
            next.frame = (wrapped % count + count) % count
        } else {
            let (sum, overflow) = state.frame.addingReportingOverflow(frames)
            next.frame = clamped(overflow ? (frames > 0 ? Int.max : Int.min) : sum, state)
        }
        return next
    }

    public func toStart(_ state: TransportState) -> TransportState {
        guard reason(state) == nil else { return state }
        var next = state
        next.frame = 0
        return next
    }

    public func toEnd(_ state: TransportState) -> TransportState {
        guard reason(state) == nil else { return state }
        var next = state
        next.frame = state.frameCount - 1
        return next
    }

    public func face(_ state: TransportState) -> TransportFace {
        let title = state.isPlaying ? "Pause" : "Play"
        if let reason = reason(state) {
            return TransportFace(playTitle: title, unavailableHelp: reason, timecode: "--:-- / --:--")
        }
        let fps = state.fps
        let current = clamped(state.frame, state)
        func code(_ frame: Int) -> String {
            let (seconds, frames) = frame.quotientAndRemainder(dividingBy: fps)
            return "\(seconds < 10 ? "0" : "")\(seconds):\(frames < 10 ? "0" : "")\(frames)"
        }
        func spoken(_ frame: Int) -> String {
            let (seconds, frames) = frame.quotientAndRemainder(dividingBy: fps)
            return "\(seconds) second\(seconds == 1 ? "" : "s") and \(frames) frame\(frames == 1 ? "" : "s")"
        }
        return TransportFace(
            playTitle: title, unavailableHelp: nil,
            timecode: "\(code(current)) / \(code(state.frameCount))",
            timecodeHelp: "Seconds:frames at \(fps) fps: \(spoken(current)) of \(spoken(state.frameCount)).")
    }
}
