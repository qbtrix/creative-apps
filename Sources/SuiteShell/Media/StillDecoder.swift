// StillDecoder.swift: the shell's still decoder (shell-media SM-7), the
// decode half of Photo's ImageIOCodec moved into the suite. It reads any
// still ImageIO knows (PNG, JPEG, HEIC, TIFF, ...), turns it upright by its
// EXIF orientation, shrinks it so its longest side is at most `longestSide`
// (never enlarging), and draws it into 8-bit sRGB. A bitmap context only
// holds premultiplied alpha, so the bytes are unpremultiplied afterwards:
// a MediaFrame carries straight alpha, top row first.
import Accelerate
import CoreGraphics
import Foundation
import ImageIO
import SuiteModel

public struct StillDecoder: Sendable {
    public init() {}

    /// The first image in `data`, upright, at most `longestSide` on its longer side.
    public func still(_ data: Data, longestSide: Int?) throws(SuiteError) -> MediaFrame {
        if let longestSide, longestSide < 1 {
            throw .notAvailable("A still can't be shrunk below 1 pixel.")
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0,
            let stored = Self.storedLongestSide(source)
        else { throw .readFailed("This isn't an image the Mac can read.") }
        let limit = min(longestSide ?? stored, stored)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: limit,
        ]
        guard let upright = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
            let rgba = Self.straightRGBA(upright)
        else { throw .readFailed("The still couldn't be decoded.") }
        return try MediaFrame(width: upright.width, height: upright.height, rgba: rgba)
    }

    /// The longer of the stored pixel width and height, before any orientation.
    static func storedLongestSide(_ source: CGImageSource) -> Int? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int,
            width > 0, height > 0
        else { return nil }
        return max(width, height)
    }

    /// `image` drawn into 8-bit sRGB RGBA with straight alpha, top row first.
    static func straightRGBA(_ image: CGImage) -> [UInt8]? {
        let width = image.width, height = image.height
        guard width > 0, height > 0, let sRGB = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let rowBytes = width * 4
        var pixels = [UInt8](repeating: 0, count: rowBytes * height)
        let ok = pixels.withUnsafeMutableBytes { raw -> Bool in
            guard let base = raw.baseAddress,
                let bitmap = CGContext(
                    data: base, width: width, height: height, bitsPerComponent: 8, bytesPerRow: rowBytes,
                    space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            bitmap.draw(image, in: CGRect(origin: .zero, size: CGSize(width: width, height: height)))
            var buffer = vImage_Buffer(
                data: base, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: rowBytes)
            return vImageUnpremultiplyData_RGBA8888(&buffer, &buffer, vImage_Flags(kvImageNoFlags)) == kvImageNoError
        }
        return ok ? pixels : nil
    }
}
