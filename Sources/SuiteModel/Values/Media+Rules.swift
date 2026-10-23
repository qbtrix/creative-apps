// Media+Rules.swift: what each codec and format can write (shell-media SM-3).
// Sizes 16...8192; H.264 and HEVC (4:2:0 chroma) refuse odd sizes; fps
// 1...120 for movies and APNG, 1...50 for GIF (its delays are centiseconds);
// quality 0...1; loop count 0 (forever)...65,535 (the field is 16 bits).
// Alpha needs no rule: the codec carries it (`MovieCodec.keepsAlpha`), so a
// setting can't ask for alpha its codec drops. Every refusal is
// `SuiteError.notAvailable` with a sentence a person can act on.

/// The bounds the media writers accept.
enum MediaRules {
    static let maxSide = 8192
    static let minSide = 16
    static let maxMovieFPS = 120
    static let maxGIFFPS = 50
    static let maxLoopCount = 65_535

    static func checkSize(_ width: Int, _ height: Int) throws(SuiteError) {
        guard width >= minSide, height >= minSide, width <= maxSide, height <= maxSide else {
            throw .notAvailable(
                "Width and height must be from \(minSide) to \(maxSide) pixels, not \(width) by \(height).")
        }
    }

    static func checkRate(_ fps: Int, max: Int, for name: String) throws(SuiteError) {
        guard fps >= 1, fps <= max else {
            throw .notAvailable("\(name) runs at 1 to \(max) frames a second, not \(fps).")
        }
    }
}

extension MovieCodec {
    /// The codec's name in a sentence.
    var displayName: String {
        switch self {
        case .h264: "H.264"
        case .hevc: "HEVC"
        case .hevcAlpha: "HEVC with alpha"
        case .prores4444: "ProRes 4444"
        }
    }
}

extension MovieSettings {
    /// These settings unchanged, or `notAvailable` naming the first rule they break.
    public func validated() throws(SuiteError) -> MovieSettings {
        try MediaRules.checkSize(width, height)
        if codec.needsEvenSize, !width.isMultiple(of: 2) || !height.isMultiple(of: 2) {
            throw .notAvailable("Width and height must be even for \(codec.displayName).")
        }
        try MediaRules.checkRate(fps, max: MediaRules.maxMovieFPS, for: "A movie")
        guard quality >= 0, quality <= 1 else {
            throw .notAvailable("Quality must be from 0 to 1, not \(quality).")
        }
        return self
    }
}

extension AnimatedImageSettings {
    /// These settings unchanged, or `notAvailable` naming the first rule they break.
    public func validated() throws(SuiteError) -> AnimatedImageSettings {
        try MediaRules.checkSize(width, height)
        switch format {
        case .gif: try MediaRules.checkRate(fps, max: MediaRules.maxGIFFPS, for: "A GIF")
        case .apng: try MediaRules.checkRate(fps, max: MediaRules.maxMovieFPS, for: "An APNG")
        }
        guard loopCount >= 0, loopCount <= MediaRules.maxLoopCount else {
            throw .notAvailable(
                "The loop count must be from 0 (forever) to \(MediaRules.maxLoopCount), not \(loopCount).")
        }
        return self
    }
}
