// PlacedImageView.swift: the one draw of a placed image (placed-images PL-3): a PNG or JPEG drawn by
// `PlaceRules.drawnRect`, clipped to the box with its corners; an SVG keeps the PL-2 placeholder, a grey box with the
// file's name, until PL-8 draws the vector. A raster is decoded once per asset id and kept in `PlacedRaster`. A SwiftUI
// `Canvas` renderer calls `drawPlaced` directly; `PlacedImageView` wraps it in a view the size of the box.
import CoreGraphics
import Foundation
import ImageIO
import SuiteKernel
import SwiftUI
import Synchronization

extension GraphicsContext {
    /// Draws `asset` for `image`: clipped to `image.box` with `cornerRadius`, at `drawnRect`, both times `scale`.
    /// `strokes: false` draws an SVG's fills only (Halo, whose CoreRaster render has no stroker yet).
    public func drawPlaced(
        _ asset: PlacedAsset, _ image: PlacedImage, cornerRadius: Double = 0, scale: Double = 1, strokes: Bool = true
    ) {
        let box = PlacedImageText.cgRect(image.box, scale: scale)
        let drawn = PlacedImageText.cgRect(PlaceRules.drawnRect(image, natural: asset.natural), scale: scale)
        var context = self
        context.clip(to: Path(roundedRect: box, cornerRadius: cornerRadius * scale))
        if asset.format != .svg, let raster = PlacedRaster.image(asset) {
            context.draw(Image(decorative: raster, scale: 1), in: drawn)
            return
        }
        context.fill(Path(drawn), with: .color(SuiteColor.valueFill))
        context.draw(
            Text(asset.name).font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText),
            at: CGPoint(x: box.midX, y: box.midY))
    }
}

/// Decoded rasters by asset id, so a redraw never decodes again; at most `limit`, emptied when full.
enum PlacedRaster {
    static let limit = 16
    private static let decoded = Mutex<[String: CGImage]>([:])

    /// `asset`'s picture; nil when ImageIO can't decode its bytes.
    static func image(_ asset: PlacedAsset) -> CGImage? {
        if let held = decoded.withLock({ $0[asset.id] }) { return held }
        guard let source = CGImageSourceCreateWithData(asset.data as CFData, nil),
            let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else { return nil }
        decoded.withLock { images in
            if images.count >= limit { images.removeAll() }
            images[asset.id] = image
        }
        return image
    }

    /// The asset for `data` named `name`: its format sniffed, its natural size from ImageIO (a raster) or the SVG's
    /// own size; nil when the bytes are none of `PlacedFormat` or carry no size.
    static func asset(name: String, data: Data) -> PlacedAsset? {
        guard let format = PlaceRules.format(of: data) else { return nil }
        let natural: Size
        if format == .svg {
            guard let vector = try? PlaceRules.vector(data, name: name) else { return nil }
            natural = vector.size
        } else {
            guard let source = CGImageSourceCreateWithData(data as CFData, nil),
                let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
                let height = properties[kCGImagePropertyPixelHeight] as? NSNumber
            else { return nil }
            natural = Size(width: width.doubleValue, height: height.doubleValue)
        }
        guard natural.width > 0, natural.height > 0 else { return nil }
        return PlacedAsset(id: PlaceRules.assetID(of: data), name: name, format: format, natural: natural, data: data)
    }
}

/// A placed image as a view the size of its box.
public struct PlacedImageView: View {
    private let asset: PlacedAsset
    private let image: PlacedImage
    private let cornerRadius: Double

    public init(asset: PlacedAsset, image: PlacedImage, cornerRadius: Double = 0) {
        (self.asset, self.image, self.cornerRadius) = (asset, image, cornerRadius)
    }

    public var body: some View {
        let box = image.box
        Canvas { context, _ in
            context.translateBy(x: -box.minX, y: -box.minY)
            context.drawPlaced(asset, image, cornerRadius: cornerRadius)
        }
        .frame(width: box.width, height: box.height)
        .accessibilityElement()
        .accessibilityLabel("Image")
        .accessibilityValue(PlacedImageText.spoken(asset))
    }
}
