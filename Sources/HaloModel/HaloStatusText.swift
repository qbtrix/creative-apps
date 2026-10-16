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

    /// The viewer status bar's timecode pill: the playhead's timecode
    /// (HaloTimeline), then its frame, so it matches the ruler
    /// ("00:00:00:20 · frame 20"). The timecode leads, so journeys can match on
    /// its prefix. The length and rate live in the tooltip: the status bar
    /// shares the content column with the layer count and the transport, and
    /// must fit it at the 1000 pt window.
    public var statusTimecode: String { "\(playheadTimecode) · frame \(playheadFrame)" }

    /// The length and rate the tooltip ends with ("3 s at 24 fps").
    public var statusLengthText: String { "\(durationText) at \(frameRateText)" }

    /// The timecode pill's tooltip: what its parts count, the frame range and
    /// the length ("Hours:minutes:seconds:frames, then the frame, at the
    /// playhead (frame 45 of 0–299). The composition runs 10 s at 30 fps.").
    public var statusTimecodeHelp: String {
        "Hours:minutes:seconds:frames, then the frame, at the playhead (frame \(playheadFrame) of 0–\(lastFrame)). "
            + "The composition runs \(statusLengthText)."
    }

    /// The viewer status bar's tooltip over its zoom and size pills.
    public static let viewerPillsHelp = "Viewer zoom, then the composition size in pixels."

    /// The inspector Size row's tooltip: what the size counts.
    public static let sizeHelp = "Width × height in pixels."

    /// The unit the New Composition sheet shows after its Width and Height fields.
    public static let sizeUnit = "px"
}
