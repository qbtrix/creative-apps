// RawFormat.swift: the values of the suite's one RAW decode (shared-raw SR-2
// stubs, SR-3 bodies). Which files are RAW is the format registry's camera RAW
// row (`SuiteImageFormat.cameraRaw`), never a list of this module's; why a
// file can't be read is one of `RawRefusal`'s four sentences; and
// `RawDecodePlan` says how much picture a request decodes: the camera's
// embedded preview, a draft develop or every pixel. Linux-safe.

/// A camera RAW file's extension, upper case as the refusals name it ("NEF"). Which extensions are RAW is
/// the registry's: `SuiteImageFormat.cameraRaw.extensions` (shared-codecs SC-14).
public struct RawFormat: Hashable, Sendable, Codable {
    public let fileExtension: String

    /// Non-nil when the registry's format for `fileName` is in the `.cameraRaw` family, any case.
    /// SR-2 stub: nil; SR-3 reads the registry.
    public init?(fileName: String) {
        return nil
    }

    /// A format named by `fileExtension` as is, for this module's decoders, which
    /// have already matched the file to a row.
    init(checkedExtension: String) {
        fileExtension = checkedExtension.uppercased()
    }
}

/// Why a RAW file can't be read or developed; `message` is the sentence the apps show.
public enum RawRefusal: Error, Equatable, Sendable {
    case unreadable(RawFormat)                // "macOS can't read this raw file (NEF)."
    case undevelopable(camera: String)        // "macOS can't develop raw files from <camera> yet."
    case unavailable                          // "This build can't read raw files. Open it on a Mac."
    case tooLarge(pixels: Int)                // "This raw file is larger than 256 megapixels."

    /// SR-2 stub: empty; SR-3 writes the four sentences.
    public var message: String { "" }
}

/// A pixel size, upright (orientation applied).
public struct RawSize: Hashable, Sendable {
    public var width, height: Int
    public var longSide: Int { max(width, height) }

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }
}

/// What the decoder says about one file.
public struct RawFileInfo: Hashable, Sendable {
    public var format: RawFormat
    public var camera: String                 // "AfterGlow Test"; "this camera" when the file names none
    public var developable: Bool
    public var size: RawSize                  // full decoded size
    public var previewSize: RawSize?          // the embedded preview; nil when there is none
    public var baselineStops: Double          // the file's baseline exposure, applied by `decode`

    public init(format: RawFormat, camera: String, developable: Bool, size: RawSize,
                previewSize: RawSize?, baselineStops: Double) {
        self.format = format
        self.camera = camera
        self.developable = developable
        self.size = size
        self.previewSize = previewSize
        self.baselineStops = baselineStops
    }
}

/// How much picture a caller needs.
public enum RawQuality: Hashable, Sendable {
    case thumbnail(longestSide: Int)          // the embedded preview may stand in
    case preview(longestSide: Int)            // a draft decode at that size
    case full                                 // every pixel, never draft: the loupe at 100 %, Photo, export
}

/// What `SuiteRaw.decode` asks the decoder for.
public enum RawDecodePlan: Hashable, Sendable {
    case embeddedPreview(longestSide: Int)
    case develop(scale: Double, draft: Bool)
    case refuse(RawRefusal)

    /// SR-2 stub: refuses `.unavailable`; SR-3 picks the preview, a draft or every pixel.
    public static func plan(_ quality: RawQuality, info: RawFileInfo) -> RawDecodePlan {
        .refuse(.unavailable)
    }
}

/// Hashable on top of the contract's Equatable, so `RawDecodePlan.refuse` can be.
extension RawRefusal: Hashable {}
