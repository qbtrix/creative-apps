// StillEncoder.swift: shell-media's still encoder (SM-6), the encode half of
// Photo's ImageIOCodec moved into the suite. It writes one MediaFrame as PNG,
// JPEG, HEIC or TIFF through one ImageIO destination. PNG, TIFF and HEIC keep
// the frame's alpha; JPEG has none, so the frame is drawn over opaque white
// first. `quality` (0 to 1, clamped) sets the lossy compression of JPEG and
// HEIC; PNG and TIFF are lossless and ignore it. `image(_:)` is also how
// AnimatedImageWriter turns a frame into an image.
import CoreGraphics
import Foundation
import ImageIO
import SuiteModel
import UniformTypeIdentifiers

public struct StillEncoder: Sendable {
    public init() {}

    /// `frame` encoded as `format`, the bytes of a complete file.
    public func still(_ frame: MediaFrame, as format: StillFormat, quality: Double) throws(SuiteError) -> Data {
        let image = format == .jpeg ? Self.opaque(frame) : Self.image(frame)
        guard let image else { throw .notAvailable("The frame's pixels couldn't be read.") }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, Self.type(format), 1, nil) else {
            throw .notAvailable("This Mac can't write \(Self.name(format)) images.")
        }
        var properties: [CFString: Any] = [:]
        if format == .jpeg || format == .heic {
            properties[kCGImageDestinationLossyCompressionQuality] = min(max(quality, 0), 1)
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw .ioFailed("the \(Self.name(format)) image couldn't be encoded")
        }
        return data as Data
    }

    static func type(_ format: StillFormat) -> CFString {
        let type: UTType = switch format {
        case .png: .png
        case .jpeg: .jpeg
        case .heic: .heic
        case .tiff: .tiff
        }
        return type.identifier as CFString
    }

    static func name(_ format: StillFormat) -> String {
        switch format {
        case .png: "PNG"
        case .jpeg: "JPEG"
        case .heic: "HEIC"
        case .tiff: "TIFF"
        }
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
