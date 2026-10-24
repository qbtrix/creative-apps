// ImageIOCodec.swift: PhotoModel's PhotoImageCodec on the Mac, a conformance
// over the suite's one image adapter, SuiteImageIO (shared-codecs SC-4).
// Decoding reads any image the Mac knows: PNG and JPEG by creative-core (a
// JPEG turned upright by its Exif orientation), everything else by ImageIO,
// shrunk to `longestSide` when asked, then handed to the model as 8-bit
// straight sRGB. Encoding writes PNG or JPEG (at the given quality) through
// creative-core. Errors say what went wrong in words a person can act on.
import CoreRaster
import Foundation
import PhotoModel
import SuiteShell

struct ImageIOCodec: PhotoImageCodec {
    enum Failure: Error, CustomStringConvertible {
        case unreadable, unwritable

        var description: String {
            switch self {
            case .unreadable: "Photo can't read this kind of file."
            case .unwritable: "The image couldn't be written."
            }
        }
    }

    /// The upright pixel size of the image file at `url`, read without decoding it; nil if the Mac can't read it.
    static func pixelSize(of url: URL) -> (width: Int, height: Int)? {
        guard let info = try? SuiteImageIO.info(url) else { return nil }
        return (info.width, info.height)
    }

    func decode(_ data: Data, longestSide: Int?) throws -> DecodedImage {
        do {
            let buffer = try SuiteImageIO.decode(data, longestSide: longestSide)
            return DecodedImage(rgba8: try buffer.rgba8(), width: buffer.width, height: buffer.height)
        } catch {
            throw Failure.unreadable
        }
    }

    func encode(_ image: DecodedImage, as format: ImageFormat, quality: Double) throws -> Data {
        do {
            let buffer = try PixelBuffer(rgba8: image.rgba8, width: image.width, height: image.height)
            // One branch per format, not a ternary: two formats on one line are a list (FormatListRatchetTests).
            if format == .png { return try SuiteImageIO.encode(buffer, as: .png) }
            return try SuiteImageIO.encode(buffer, as: .jpeg(quality: quality))
        } catch {
            throw Failure.unwritable
        }
    }
}
