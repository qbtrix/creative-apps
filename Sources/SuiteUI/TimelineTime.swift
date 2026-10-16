// TimelineTime.swift: how the timeline shows time (timeline packet, TL-16;
// the ruler and pill use it in TL-18, and hosts use `label` for their own
// readout so all three agree). Frames read "30"; timecode reads "MM:SS:FF"
// ("00:01:06" at 24 fps) and "H:MM:SS:FF" from an hour on. No fps (0 or
// less) reads frames, never a division by zero. In timecode the ruler's
// labels sit on whole seconds once the frame step reaches fps / 2. Plain
// math, no SwiftUI (TimelineNavTests).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public enum TimelineTime {
    /// `frame` as the ruler, the playhead pill and a host's readout show it.
    public static func label(frame: Int, fps: Int, unit: TimeUnit) -> String {
        guard unit == .timecode, fps > 0 else { return "\(frame)" }
        let rate = UInt(fps), f = frame.magnitude
        let ff = f % rate, seconds = f / rate
        let ss = seconds % 60, mm = (seconds / 60) % 60, hh = seconds / 3600
        let sign = frame < 0 ? "-" : ""
        let tail = "\(pad(mm)):\(pad(ss)):\(pad(ff))"
        return hh > 0 ? "\(sign)\(hh):\(tail)" : "\(sign)\(tail)"
    }

    /// The ruler's label step: `step` (at least 1), raised to whole seconds
    /// in timecode once it reaches fps / 2.
    public static func labelStep(_ step: Int, fps: Int, unit: TimeUnit) -> Int {
        let step = max(step, 1)
        guard unit == .timecode, fps > 0, step * 2 >= fps else { return step }
        return (step + fps - 1) / fps * fps
    }

    /// The labelled frames inside `range`: the multiples of `labelStep`.
    public static func labelFrames(in range: ClosedRange<Int>, step: Int, fps: Int, unit: TimeUnit) -> [Int] {
        let step = labelStep(step, fps: fps, unit: unit)
        let low = range.lowerBound
        // The first multiple of `step` at or above `low`, for negative `low` too.
        let first = low >= 0 ? (low + step - 1) / step * step : -((-low) / step * step)
        return Array(stride(from: first, through: range.upperBound, by: step))
    }

    /// Two digits at least: 6 reads "06".
    private static func pad(_ value: UInt) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
