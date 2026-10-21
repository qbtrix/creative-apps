// PlacedImageView.swift: the one draw of a placed image (placed-images PL-2 placeholder: a grey box with the file's
// name at `PlaceRules.drawnRect`, clipped to the box; PL-3 draws the raster, PL-8 the vector). A SwiftUI `Canvas`
// renderer calls `drawPlaced` directly; `PlacedImageView` wraps it in a view the size of the box.
import SuiteKernel
import SwiftUI

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
        context.fill(Path(drawn), with: .color(SuiteColor.valueFill))
        context.draw(
            Text(asset.name).font(SuiteFont.caption).foregroundStyle(SuiteColor.secondaryText),
            at: CGPoint(x: box.midX, y: box.midY))
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
