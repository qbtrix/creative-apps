// SuiteRaw.swift: the suite's one RAW decode (shared-raw SR-2 contract, SR-3
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

    /// What `decoder` says about the file; `.unavailable` without one.
    public static func info(_ source: RawSource, decoder: (any RawDecoding)? = SuiteRaw.decoder) throws(RawRefusal) -> RawFileInfo {
        guard let decoder else { throw .unavailable }
        return try decoder.info(source)
    }

    /// The working space (extended-range linear sRGB), Float32, premultiplied, upright; values above 1 and
    /// outside sRGB kept. The file's baseline exposure is applied
    /// here as one core `exposure(stops:)` step; an embedded preview comes back as decoded (no baseline).
    /// A develop larger than `PixelBuffer.maxPixels` is refused `.tooLarge` before the decoder allocates it.
    public static func decode(_ source: RawSource, quality: RawQuality,
                              decoder: (any RawDecoding)? = SuiteRaw.decoder) throws(RawRefusal) -> PixelBuffer {
        guard let decoder else { throw .unavailable }
        let info = try decoder.info(source)
        switch RawDecodePlan.plan(quality, info: info) {
        case .refuse(let refusal):
            throw refusal
        case .embeddedPreview(let longestSide):
            return try decoder.embeddedPreview(source, longestSide: longestSide)
        case .develop(let scale, let draft):
            let pixels = developedPixels(info.size, scale: scale)
            guard pixels <= PixelBuffer.maxPixels else { throw .tooLarge(pixels: pixels) }
            let developed = try decoder.develop(source, scale: scale, draft: draft)
            do {
                return try developed.exposure(stops: Float(info.baselineStops))
            } catch {
                throw .unreadable(info.format)
            }
        }
    }

    /// The pixel count of `size` at `scale`, rounded as a decoder rounds it; Int.max when it overflows.
    static func developedPixels(_ size: RawSize, scale: Double) -> Int {
        let width = (Double(size.width) * scale).rounded(), height = (Double(size.height) * scale).rounded()
        let pixels = width * height
        guard pixels.isFinite, pixels < Double(Int.max) else { return Int.max }
        return max(0, Int(pixels))
    }
}
