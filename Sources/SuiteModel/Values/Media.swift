// Media.swift: the values of the suite's one media service (shell-media
// SM-1): a frame of 8-bit sRGB bytes, the codecs and formats it writes, the
// settings of a movie or an animated image, and what a movie file holds.
// Settings rules (`validated()`) are SM-3's Media+Rules.swift; the frame
// clock is SM-4's FrameClock.swift. Foundation free, Linux-safe, Sendable.

/// One picture: 8-bit sRGB, straight alpha, top row first, 4 bytes a pixel.
/// The shape Photo's `DecodedImage` and Halo's rendered frames already use.
public struct MediaFrame: Sendable, Equatable {
    public let width: Int, height: Int
    public let rgba: [UInt8]

    /// Refuses a size below 1 x 1 or a byte count other than width x height x 4.
    public init(width: Int, height: Int, rgba: [UInt8]) throws(SuiteError) {
        let pixels = width.multipliedReportingOverflow(by: height)
        let bytes = pixels.partialValue.multipliedReportingOverflow(by: 4)
        guard width > 0, height > 0, !pixels.overflow, !bytes.overflow else {
            throw .notAvailable("A frame must be at least 1 by 1 pixel and fit in memory.")
        }
        if rgba.count != bytes.partialValue {
            throw .notAvailable("A \(width) by \(height) frame needs \(bytes.partialValue) bytes, not \(rgba.count).")
        }
        self.width = width; self.height = height; self.rgba = rgba
    }
}

/// The movie codecs the suite writes.
public enum MovieCodec: String, Codable, Sendable, CaseIterable {
    case h264, hevc, hevcAlpha, prores4444

    /// Whether the file keeps the frame's alpha; the others draw over opaque black.
    public var keepsAlpha: Bool { self == .hevcAlpha || self == .prores4444 }
    /// 4:2:0 chroma: width and height must be even.
    public var needsEvenSize: Bool { self != .prores4444 }
}

/// The animated image formats the suite writes.
public enum AnimatedImageFormat: String, Codable, Sendable, CaseIterable { case gif, apng }

/// The still image formats the suite writes: `SuiteImageFormats.writable`, never a list of its own.
/// Coded and spelled as the format's id ("png", "jpeg", "heic", "tiff").
public struct StillFormat: RawRepresentable, Hashable, Codable, Sendable, CaseIterable {
    public let format: SuiteImageFormat
    public var rawValue: String { format.rawValue }

    private init(writable format: SuiteImageFormat) { self.format = format }

    /// Nil for a format the suite only reads.
    public init?(_ format: SuiteImageFormat) {
        guard SuiteImageFormats.writable.contains(format) else { return nil }
        self.init(writable: format)
    }

    // One per writable format; MediaContractTests ties them to `allCases`.
    public static let png = StillFormat(writable: .png)
    public static let jpeg = StillFormat(writable: .jpeg)
    public static let heic = StillFormat(writable: .heic)
    public static let tiff = StillFormat(writable: .tiff)

    public init?(rawValue: String) {
        guard let format = SuiteImageFormat(rawValue: rawValue) else { return nil }
        self.init(format)
    }

    public static var allCases: [StillFormat] { SuiteImageFormats.writable.compactMap { StillFormat($0) } }
}

/// What a movie is written as: its size, its whole-number rate, its codec and
/// a quality from 0 to 1.
public struct MovieSettings: Hashable, Codable, Sendable {
    public var width: Int, height: Int, fps: Int
    public var codec: MovieCodec
    public var quality: Double

    public init(width: Int, height: Int, fps: Int, codec: MovieCodec, quality: Double) {
        self.width = width; self.height = height; self.fps = fps; self.codec = codec; self.quality = quality
    }
}

/// What a GIF or APNG is written as; a loop count of 0 loops forever.
public struct AnimatedImageSettings: Hashable, Codable, Sendable {
    public var width: Int, height: Int, fps: Int
    public var format: AnimatedImageFormat
    public var loopCount: Int

    public init(width: Int, height: Int, fps: Int, format: AnimatedImageFormat, loopCount: Int) {
        self.width = width; self.height = height; self.fps = fps; self.format = format; self.loopCount = loopCount
    }
}

/// What a movie file holds, read from its video track.
public struct MediaInfo: Hashable, Codable, Sendable {
    public var width: Int, height: Int
    public var seconds: Double, fps: Double
    public var frameCount: Int
    public var hasAlpha: Bool, hasAudio: Bool
    /// The track's codec, as the system names it (for example "avc1").
    public var codec: String

    public init(width: Int, height: Int, seconds: Double, fps: Double, frameCount: Int,
                hasAlpha: Bool, hasAudio: Bool, codec: String) {
        self.width = width; self.height = height; self.seconds = seconds; self.fps = fps
        self.frameCount = frameCount; self.hasAlpha = hasAlpha; self.hasAudio = hasAudio; self.codec = codec
    }
}
