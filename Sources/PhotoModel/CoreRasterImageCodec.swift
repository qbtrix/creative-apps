// CoreRasterImageCodec.swift (adopt-command-catalog AC-p2, shared-codecs SC-4): PhotoImageCodec over creative-core's
// PNG and JPEG codecs, for the headless document and Linux. Pixels cross as CoreRaster's premultiplied linear
// PixelBuffer, as core's codecs take them. Every PNG and JPEG is core's, both ways: a file core refuses is refused,
// never read another way, and a JPEG is turned upright by its Exif orientation (CIPA DC-008 values 1 to 8).
// Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import SuiteImaging
import SuiteModel

/// PNG and JPEG through CoreRaster; HEIC, TIFF and PSD through the system on macOS.
public struct CoreRasterImageCodec: PhotoImageCodec {
    public init() {}

    /// The files CoreRaster reads itself.
    static let rasterExtensions = SuiteImageFormat.png.extensions
        + SuiteImageFormat.jpeg.extensions

    public var readExtensions: Set<String> { Set(Self.rasterExtensions).union(SystemImageDecoder.extensions) }

    public func decode(_ data: Data, longestSide: Int?) throws -> DecodedImage {
        if !data.starts(with: Self.signature), !data.starts(with: [0xFF, 0xD8, 0xFF]),
           let image = SystemImageDecoder.decode(data, longestSide: longestSide) {
            return DecodedImage(rgba8: image.rgba8, width: image.width, height: image.height)
        }
        var buffer = try Self.read(data)
        let longest = max(buffer.width, buffer.height)
        if let side = longestSide, side > 0, longest > side {
            let scale = Double(side) / Double(longest)
            buffer = try buffer.resized(width: max(Int((Double(buffer.width) * scale).rounded()), 1),
                                        height: max(Int((Double(buffer.height) * scale).rounded()), 1), filter: .bilinear)
        }
        return DecodedImage(rgba8: try buffer.rgba8(), width: buffer.width, height: buffer.height)
    }

    public func encode(_ image: DecodedImage, as format: ImageFormat, quality: Double) throws -> Data {
        let buffer = try PixelBuffer(rgba8: image.rgba8, width: image.width, height: image.height)
        // One branch per format, not a switch: a switch over formats is a list (FormatListRatchetTests).
        if format == .png { return try PNG.write(buffer) }
        return try JPEG.write(buffer, quality: Int((min(max(quality, 0), 1) * 100).rounded()))
    }

    static let signature: [UInt8] = [137, 80, 78, 71, 13, 10, 26, 10]

    /// `data` as a premultiplied linear buffer: core's PNG reader for a PNG signature, core's JPEG reader (and
    /// the Exif orientation) for anything else. Core's errors pass through.
    static func read(_ data: Data) throws -> PixelBuffer {
        guard data.starts(with: signature) else { return upright(try JPEG.read(data), orientation: try JPEG.info(data).orientation) }
        return try PNG.read(data)
    }

    /// `stored` as shown for Exif `orientation`: 2 mirrors, 3 turns half round, 4 flips, 5 and 7 turn a quarter
    /// and mirror, 6 turns a quarter clockwise, 8 a quarter anticlockwise; 1 and unknown values leave it.
    static func upright(_ stored: PixelBuffer, orientation: Int) -> PixelBuffer {
        switch orientation {
        case 2: stored.flipped(.horizontal)
        case 3: stored.rotated(.degrees180)
        case 4: stored.flipped(.vertical)
        case 5: stored.rotated(.degrees90).flipped(.horizontal)
        case 6: stored.rotated(.degrees90)
        case 7: stored.rotated(.degrees270).flipped(.horizontal)
        case 8: stored.rotated(.degrees270)
        default: stored
        }
    }
}
