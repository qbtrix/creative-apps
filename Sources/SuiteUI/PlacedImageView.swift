// PlacedImageView.swift: the one draw of a placed image (placed-images PL-3, PL-8): a PNG or JPEG, or an SVG's
// `PlacedVector` (even-odd fills through `Fill.shading`, strokes at their width), drawn by `PlaceRules.drawnRect` and
// clipped to the box with its corners; bytes that read as neither draw a grey box with the file's name. A raster is
// decoded, and a vector flattened, once per asset id and kept in `PlacedRaster`. A SwiftUI `Canvas` renderer calls
// `drawPlaced` directly; `PlacedImageView` wraps it in a view the size of the box.
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
        if asset.format == .svg, let vector = PlacedRaster.vector(asset) {
            context.drawVector(vector, in: drawn, strokes: strokes)
            return
        }
        context.fill(Path(drawn), with: .color(SuiteColor.valueFill))
        context.draw(
            Text(asset.name).font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText),
            at: CGPoint(x: box.midX, y: box.midY))
    }

    /// `vector`'s items in paint order, from its own units into `rect`: each fill even-odd, each stroke at its width
    /// times the scale, each item at its opacity.
    fileprivate func drawVector(_ vector: PlacedVector, in rect: CGRect, strokes: Bool) {
        guard vector.size.width > 0, vector.size.height > 0 else { return }
        let (sx, sy) = (Double(rect.width) / vector.size.width, Double(rect.height) / vector.size.height)
        let units = Rect(minX: 0, minY: 0, maxX: vector.size.width, maxY: vector.size.height)
        for item in vector.items {
            var path = Path()
            for contour in item.contours where contour.count > 1 {
                path.addLines(contour.map { CGPoint(x: Double(rect.minX) + $0.x * sx, y: Double(rect.minY) + $0.y * sy) })
                path.closeSubpath()
            }
            var layer = self
            layer.opacity *= item.opacity
            if let fill = item.fill { layer.fill(path, with: fill.shading(in: rect, box: units), style: FillStyle(eoFill: true)) }
            if strokes, let color = item.strokeColor, item.strokeWidth > 0 {
                layer.stroke(path, with: .color(color.swiftUI), lineWidth: item.strokeWidth * min(sx, sy))
            }
        }
    }
}

/// Decoded rasters by asset id, so a redraw never decodes again; at most `limit`, emptied when full.
enum PlacedRaster {
    static let limit = 16
    private static let decoded = Mutex<[String: CGImage]>([:])
    private static let flattened = Mutex<[String: PlacedVector]>([:])

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

    /// `asset`'s SVG flattened for drawing; nil when its bytes don't import.
    static func vector(_ asset: PlacedAsset) -> PlacedVector? {
        if let held = flattened.withLock({ $0[asset.id] }) { return held }
        guard let vector = try? PlaceRules.vector(asset.data, name: asset.name) else { return nil }
        flattened.withLock { vectors in
            if vectors.count >= limit { vectors.removeAll() }
            vectors[asset.id] = vector
        }
        return vector
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
