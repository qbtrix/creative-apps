// StillEncoder.swift: shell-media's still encoder (SM-6), the encode half of
// Photo's ImageIOCodec moved into the suite. It writes one MediaFrame as PNG,
// JPEG, HEIC or TIFF through SuiteImageIO. PNG, TIFF and HEIC keep
// the frame's alpha; JPEG has none, so the frame is drawn over opaque white
// first. `quality` (0 to 1, clamped) sets the lossy compression of JPEG and
// HEIC; PNG and TIFF are lossless and ignore it. `image(_:)` is also how
// AnimatedImageWriter turns a frame into an image.
import CoreGraphics
import Foundation
import SuiteModel

public struct StillEncoder: Sendable {
    public init() {}

    /// `frame` encoded as `format`, the bytes of a complete file.
    public func still(_ frame: MediaFrame, as format: StillFormat, quality: Double) throws(SuiteError) -> Data {
        let flattens = format == .jpeg
        let lossy = flattens || format == .heic
        guard let image = flattens ? Self.opaque(frame) : Self.image(frame) else {
            throw .notAvailable("The frame's pixels couldn't be read.")
        }
        return try SuiteImageIO.encode(image, as: format.format, quality: lossy ? quality : nil)
    }

    /// The frame's straight-alpha sRGB bytes as an image.
    static func image(_ frame: MediaFrame) -> CGImage? {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: Data(frame.rgba) as CFData)
        else { return nil }
        return CGImage(
            width: frame.width, height: frame.height, bitsPerComponent: 8, bitsPerPixel: 32,
            bytesPerRow: frame.width * 4, space: space,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
    }

    /// The frame drawn over opaque white, with no alpha channel.
    static func opaque(_ frame: MediaFrame) -> CGImage? {
        guard let image = image(frame), let space = CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                  data: nil, width: frame.width, height: frame.height, bitsPerComponent: 8, bytesPerRow: 0,
                  space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { return nil }
        let bounds = CGRect(x: 0, y: 0, width: frame.width, height: frame.height)
        context.setFillColor(gray: 1, alpha: 1)
        context.fill(bounds)
        context.draw(image, in: bounds)
        return context.makeImage()
    }
}
