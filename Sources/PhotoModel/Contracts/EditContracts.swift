// Contracts/EditContracts.swift: Cut, Copy and Paste of pixels, and the layer
// commands that make or combine layers: Merge Down and Flatten (PV-2).
// Duplicate Layer needs no contract (it copies a layer and its tiles).
// Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster

/// Pixels on their way to or from the pasteboard.
public struct ClipboardImage: Sendable, Equatable {
    public var image: DecodedImage
    /// Where on the canvas they were copied from; nil from another app.
    public var source: PixelRect?
    public init(image: DecodedImage, source: PixelRect?) {
        self.image = image; self.source = source
    }
}

/// PV-2: what Copy takes and where Paste puts it.
public protocol PixelClipboard: PhotoUseCase {
    /// The layer's pixels inside the selection, each weighted by `mask` when
    /// given (a feathered or lasso selection), cut to the bounds of what is
    /// not transparent. The whole layer when `selection` is nil. Nil when
    /// every pixel there is transparent ("Nothing to copy.").
    func copy(_ content: PlacedPixels, selection: PixelRect?, mask: Mask?) throws -> ClipboardImage?
    /// Where a pasted image lands: on its source rect when that still
    /// overlaps the canvas, else centered on `center` (the view's center in
    /// canvas pixels). Never off the canvas entirely.
    func placement(of image: ClipboardImage, canvas: CanvasSize, center: Mask.Point) -> PixelRect
}

/// PV-2: combine layers into one pixel layer.
public protocol LayerMerging: PhotoUseCase {
    /// `upper` composited onto `lower` with upper's blend mode, opacity and
    /// mask (an adjustment layer applies its adjustment), as one pixel layer
    /// that keeps lower's id, name, blend and opacity and covers both
    /// layers' bounds. Throws `PhotoRefusal("Merge Down needs a pixel layer
    /// below.")` when `lower` is an adjustment layer.
    func mergeDown(_ upper: LayerContent, onto lower: LayerContent) throws -> PlacedPixels
    /// Every visible layer, bottom-up, then `adjustments`, as one canvas-size
    /// layer: the same pixels Export writes before its format's background.
    /// Each layer sits at its own `offsetX`, `offsetY`. The workspace resets
    /// the whole-image adjustments to their defaults in the same step, since
    /// they are now in the pixels.
    func flatten(_ layers: [LayerContent], canvas: CanvasSize, adjustments: AdjustmentSettings) throws -> TiledPixels
}
