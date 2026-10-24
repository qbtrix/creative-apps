// RawFormat.swift: the values of the suite's one RAW decode (shared-raw SR-2
// contract, SR-3 bodies). Which files are RAW is the format registry's camera RAW
// row (`SuiteImageFormat.cameraRaw`), never a list of this module's; why a
// file can't be read is one of `RawRefusal`'s four sentences; and
// `RawDecodePlan` says how much picture a request decodes: the camera's
// embedded preview, a draft develop or every pixel. Linux-safe.
import SuiteModel

/// A camera RAW file's extension, upper case as the refusals name it ("NEF"). Which extensions are RAW is
/// the registry's: `SuiteImageFormat.cameraRaw.extensions` (shared-codecs SC-14).
public struct RawFormat: Hashable, Sendable, Codable {
    public let fileExtension: String

    /// Non-nil when the registry's format for `fileName` is in the `.cameraRaw` family, any case.
    /// The registry's `SuiteImageFormat(fileName:)` decides, so a name with no extension, or only one
    /// (".nef"), is not RAW.
    public init?(fileName: String) {
        guard let format = SuiteImageFormat(fileName: fileName), format.family == .cameraRaw,
              let dot = fileName.lastIndex(of: ".") else { return nil }
        fileExtension = fileName[fileName.index(after: dot)...].uppercased()
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

    public var message: String {
        switch self {
        case .unreadable(let format): return "macOS can't read this raw file (\(format.fileExtension))."
        case .undevelopable(let camera): return "macOS can't develop raw files from \(camera) yet."
        case .unavailable: return "This build can't read raw files. Open it on a Mac."
        case .tooLarge: return "This raw file is larger than 256 megapixels."
        }
    }
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

    /// The embedded preview for a thumbnail it covers (or any thumbnail of a file the system can't
    /// develop), a draft develop at the size a thumbnail or preview needs, every pixel for `.full`.
    /// A file that can't be developed and has no preview to stand in is refused. Scale is never above 1.
    public static func plan(_ quality: RawQuality, info: RawFileInfo) -> RawDecodePlan {
        let full = info.size.longSide
        let want: Int
        switch quality {
        case .thumbnail(let side), .preview(let side): want = max(1, min(side, full))
        case .full: want = full
        }
        let refused = RawDecodePlan.refuse(.undevelopable(camera: info.camera))
        switch quality {
        case .thumbnail:
            if let preview = info.previewSize, preview.longSide >= want || !info.developable {
                return .embeddedPreview(longestSide: want)
            }
            return info.developable ? .develop(scale: scale(want, of: full), draft: true) : refused
        case .preview:
            return info.developable ? .develop(scale: scale(want, of: full), draft: true) : refused
        case .full:
            return info.developable ? .develop(scale: 1, draft: false) : refused
        }
    }

    /// `want / full`, at most 1; 1 for a file with no size.
    static func scale(_ want: Int, of full: Int) -> Double {
        guard full > 0 else { return 1 }
        return min(1, Double(want) / Double(full))
    }
}

/// Hashable on top of the contract's Equatable, so `RawDecodePlan.refuse` can be.
extension RawRefusal: Hashable {}
