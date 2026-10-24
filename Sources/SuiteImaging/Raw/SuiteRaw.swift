// SuiteRaw.swift: the suite's one RAW decode (shared-raw SR-2 stubs, SR-3
// bodies). Photo, Library and the CLI ask it for a file's info and for its
// pixels at a `RawQuality`; it plans the decode (`RawDecodePlan`), calls the
// decoder and applies the file's baseline exposure as one core
// `exposure(stops:)` step on the float buffer, nothing else: no clamp, no
// 8-bit step. The decoder is `SystemRawDecoder` on macOS and none on Linux,
// where every call refuses `.unavailable`. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

/// Where a RAW file's bytes come from.
public enum RawSource: Sendable {
    case file(URL), bytes(Data, fileName: String)

    /// The name the format is read from.
    var fileName: String {
        switch self {
        case .file(let url): return url.lastPathComponent
        case .bytes(_, let fileName): return fileName
        }
    }
}

public enum SuiteRaw {
    /// The decoder the apps use: `SystemRawDecoder` on macOS, nil on Linux (every call refuses `.unavailable`).
    /// SR-2 stub: nil everywhere; SR-4 returns `SystemRawDecoder` on macOS.
    public static var decoder: (any RawDecoding)? { nil }

    /// SR-2 stub: refuses `.unavailable`; SR-3 asks the decoder.
    public static func info(_ source: RawSource, decoder: (any RawDecoding)? = SuiteRaw.decoder) throws(RawRefusal) -> RawFileInfo {
        throw .unavailable
    }

    /// The working space (extended-range linear sRGB), Float32, premultiplied, upright; values above 1 and
    /// outside sRGB kept. The file's baseline exposure is applied
    /// here as one core `exposure(stops:)` step; an embedded preview comes back as decoded (no baseline).
    /// SR-2 stub: refuses `.unavailable`; SR-3 plans and decodes.
    public static func decode(_ source: RawSource, quality: RawQuality,
                              decoder: (any RawDecoding)? = SuiteRaw.decoder) throws(RawRefusal) -> PixelBuffer {
        throw .unavailable
    }
}
