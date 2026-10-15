// DisplayImage+Image.swift: a LibraryModel DisplayImage (sRGB RGBA8 bytes,
// premultiplied last) drawn as a SwiftUI Image, the same way
// ThumbnailItem.image(rgba:) draws a one-pixel photo.
import LibraryModel
import SwiftUI

extension Image {
    /// The image's pixels at scale 1; a clear one-pixel image if Core
    /// Graphics refuses the bytes (DisplayImage already checked their count).
    init(display: DisplayImage) {
        let width = display.size.width, height = display.size.height
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: Data(display.rgba8) as CFData),
              let picture = CGImage(
                  width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                  space: space, bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                  provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else {
            self.init(size: CGSize(width: 1, height: 1)) { _ in }
            return
        }
        self.init(decorative: picture, scale: 1)
    }
}
