// Timecode.swift (frame-rates FR-1 stubs, FR-3 bodies): the one timecode rule, HH:MM:SS:FF at a whole rate
// and drop-frame HH:MM:SS;FF at 29.97 and 59.94 (the broadcast convention), counted in the rate's nominal frames.
// Every function is total and never traps.

/// Frame numbers to timecode labels and back, for a frame rate.
public enum Timecode {
    /// The label of `frame` at `rate`: `HH:MM:SS:FF`, or `HH:MM:SS;FF` when the rate is drop-frame.
    public static func string(frame: Int, rate: FrameRate) -> String { "00:00:00:00" }

    /// The frame `text` labels at `rate`; nil for text that isn't timecode or a label drop-frame skips.
    public static func frame(_ text: String, rate: FrameRate) -> Int? { nil }
}
