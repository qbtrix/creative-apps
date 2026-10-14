// HaloStatusText.swift: the text Halo's inspector header, Composition rows
// and viewer status bar show for a composition: its size, frame rate,
// duration and the status bar's timecode line. Built here so Linux tests cover it; views only read
// it. Integer math only, so no size, rate or length in range can trap.

extension HaloComposition {
    /// The size as the inspector and status bar show it ("1920 × 1080").
    public var sizeText: String { "\(width) × \(height)" }

    /// The frame rate ("30 fps").
    public var frameRateText: String { "\(framesPerSecond) fps" }

    /// The length in seconds to at most two decimals ("10 s", "10.03 s");
    /// "0 s" when the frame rate is not positive.
    public var durationText: String {
        guard framesPerSecond > 0 else { return "0 s" }
        let hundredths = (max(durationFrames, 0) * 100 + framesPerSecond / 2) / framesPerSecond
        let whole = hundredths / 100, fraction = hundredths % 100
        guard fraction > 0 else { return "\(whole) s" }
        let digits = fraction % 10 == 0 ? "\(fraction / 10)" : (fraction < 10 ? "0\(fraction)" : "\(fraction)")
        return "\(whole).\(digits) s"
    }

    /// The inspector header's card: the size, then rate and length.
    public var headerDetails: [String] { [sizeText, "\(frameRateText) · \(durationText)"] }

    /// The viewer status bar's trailing text: the playhead's timecode
    /// (HaloTimeline), then the length and rate ("00:00:00:00 / 10 s at 30 fps").
    public var statusTimecode: String { "\(playheadTimecode) / \(durationText) at \(frameRateText)" }
}
