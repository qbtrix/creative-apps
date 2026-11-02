// SystemRawDecoder.swift: the macOS decoder over Core Image's documented
// `CIRAWFilter` (shared-raw SR-2 stub, SR-4 body). SR-4 opens the file with
// `CIRAWFilter(imageURL:)` or `CIRAWFilter(imageData:identifierHint:)`, reads
// the camera from `properties`, develops with `boostAmount` 0 and
// `baselineExposure` 0 and renders into extended-range linear sRGB floats with
// one shared default `CIContext()`. It imports no ImageIO and no Metal
// (ImageIOImportRatchetTests, ImagingBoundaryTests). Linux builds without it.
#if canImport(CoreImage)
import CoreImage
import CoreRaster

public struct SystemRawDecoder: RawDecoding {
    public init() {}

    /// SR-2 stub: refuses `.unavailable`.
    public func info(_ source: RawSource) throws(RawRefusal) -> RawFileInfo {
        throw .unavailable
    }

    /// SR-2 stub: refuses `.unavailable`.
    public func embeddedPreview(_ source: RawSource, longestSide: Int) throws(RawRefusal) -> PixelBuffer {
        throw .unavailable
    }

    /// SR-2 stub: refuses `.unavailable`.
    public func develop(_ source: RawSource, scale: Double, draft: Bool) throws(RawRefusal) -> PixelBuffer {
        throw .unavailable
    }
}
#endif
