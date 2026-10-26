// ImageIOCodec.swift: PhotoModel's PhotoImageCodec on ImageIO. Decoding reads
// any image ImageIO knows (PNG, JPEG, HEIC, ...), applies its orientation, and
// shrinks it to `longestSide` when asked. It draws into an 8-bit sRGB
// context, which only holds premultiplied alpha, then unpremultiplies with
// Accelerate, because the model takes straight alpha. Encoding writes PNG
// (with alpha) or JPEG (opaque, at the given quality) through
// CGImageDestination. Errors say what went wrong in words a person can act on.
// `decodeLinear` (shared-raw SR-6) is the float route Photo opens every file
// through: camera RAW through `SuiteRaw`, any other format SuiteImageIO reads
// through `SuiteImageIO.decode` into the working space; until SuiteImageIO
// reads a format (shared-codecs SC-4) that file takes the 8-bit `decode`.
import Accelerate
import CoreGraphics
import CoreRaster
import Foundation
import ImageIO
import PhotoModel
import SuiteImaging
import SuiteModel
import SuiteShell
import UniformTypeIdentifiers

struct ImageIOCodec: PhotoImageCodec {
    enum Failure: Error, CustomStringConvertible {
        case unreadable, unwritable
        /// A RAW file `SuiteRaw` refused; the sentence names the format or the camera.
        case refused(RawRefusal)

        var description: String {
            switch self {
            case .unreadable: "Photo can't read this kind of file."
            case .unwritable: "The image couldn't be written."
            case .refused(let refusal): refusal.message
            }
        }
    }

    func decodeLinear(_ data: Data, fileName: String, longestSide: Int?) throws -> PixelBuffer? {
        let raw: PixelBuffer?
        do { raw = try decodeRaw(data, fileName: fileName, longestSide: longestSide) } catch { throw Failure.refused(error) }
        if let raw { return raw }
        guard let format = SuiteImageFormat(fileName: fileName), SuiteImageIO.readable.contains(format) else { return nil }
        return try SuiteImageIO.decode(data, longestSide: longestSide)
    }

    /// The pixel size ImageIO reports for the file's first image.
    static func pixelSize(of data: Data) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        return (width, height)
    }

    func decode(_ data: Data, longestSide: Int?) throws -> DecodedImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0,
            let size = Self.pixelSize(of: data)
        else { throw Failure.unreadable }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: longestSide ?? max(size.width, size.height),
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw Failure.unreadable
        }
        let (width, height) = (image.width, image.height)
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                let context = CGContext(
                    data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            var planar = vImage_Buffer(
                data: buffer.baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width),
                rowBytes: width * 4)
            return vImageUnpremultiplyData_RGBA8888(&planar, &planar, vImage_Flags(kvImageNoFlags)) == kvImageNoError
        }
        guard drawn else { throw Failure.unreadable }
        return DecodedImage(rgba8: bytes, width: width, height: height)
    }

    func encode(_ image: DecodedImage, as format: ImageFormat, quality: Double) throws -> Data {
        let alpha: CGImageAlphaInfo = format == .png ? .last : .noneSkipLast
        let type: UTType = format == .png ? .png : .jpeg
        let data = NSMutableData()
        guard let picture = CanvasRenderer.image(rgba8: image.rgba8, width: image.width, height: image.height, alpha: alpha),
            let destination = CGImageDestinationCreateWithData(data, type.identifier as CFString, 1, nil)
        else { throw Failure.unwritable }
        let properties: [CFString: Any] = format == .jpeg ? [kCGImageDestinationLossyCompressionQuality: quality] : [:]
        CGImageDestinationAddImage(destination, picture, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw Failure.unwritable }
        return data as Data
    }
}
