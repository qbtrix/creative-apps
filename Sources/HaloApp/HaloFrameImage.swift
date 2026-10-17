// HaloFrameImage.swift: a rendered frame (render-out RO-5, #451) as a
// CGImage. CoreRaster's `rgba8(colorSpace:)` gives 8-bit sRGB bytes with
// straight (unpremultiplied) alpha in R, G, B, A order, so the image is sRGB,
// 32 bits per pixel, alpha last and not premultiplied
// (`CGImageAlphaInfo.last`) in the default byte order; no local converter.
// Nil when the bytes can't be made or Core Graphics refuses them. The PNG
// writer (RO-6) writes this same image.
import CoreGraphics
import CoreRaster
import Foundation
import HaloModel

enum HaloFrameImage {
    /// `frame`'s pixels as an sRGB, straight-alpha RGBA8 image; nil when the
    /// frame has no pixels or Core Graphics refuses them.
    static func cgImage(_ frame: HaloRenderedFrame) -> CGImage? {
        let width = frame.pixels.width, height = frame.pixels.height
        guard width > 0, height > 0,
              let bytes = try? frame.pixels.rgba8(colorSpace: .sRGB),
              bytes.count == width * height * 4,
              let space = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: Data(bytes) as CFData)
        else { return nil }
        return CGImage(
            width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
            space: space, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}
