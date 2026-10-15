// Live/LiveMerging.swift: the live Merge Down and Flatten (PV-2). Both put
// each layer through PhotoLayerComposite, the renderer's per-layer step, with
// the live adjustment-layer and mask services (photo-edit review note 2), so
// they pick up adjustment layers and masks wherever the render does, and the
// picture after a merge is the render's own arithmetic. The picture stays in
// tiles throughout, composited across the cores. Linux-safe.
import CoreRaster

/// Merge Down: `lower`'s pixels placed in the union of both layers' bounds,
/// as the renderer lays a normal, fully opaque layer on transparency, then
/// `upper` composited over them with its blend mode, opacity and mask; a
/// hidden or 0 % `upper` adds nothing, as it renders. The result keeps
/// lower's place, and the workspace keeps lower's id, name, blend, opacity
/// and mask.
///
/// Limit: the render after the merge equals the render before it bit for bit
/// when `lower` is normal at 100 % with no mask (a Background) and each merged
/// pixel is opaque or empty. A lower with another blend, opacity or mask now
/// applies them to upper's contribution too, which no single layer can undo
/// in general; a partly transparent merged pixel can move by a Float rounding
/// (the composite unpremultiplies and premultiplies it again).
///
/// Flatten: every visible layer bottom-up (`layers` top first, as the stack
/// lists them) onto a transparent canvas, then the whole-image adjustments,
/// exactly as `PhotoWorkspace.composite()` renders the image.
struct LiveMerging: LayerMerging {
    var unavailableHelp: String? { nil }

    func mergeDown(_ upper: LayerContent, onto lower: LayerContent) throws -> PlacedPixels {
        guard let lowerPixels = lower.pixels else { throw PhotoRefusal("Merge Down needs a pixel layer below.") }
        let below = PixelRect(
            x: lower.layer.offsetX, y: lower.layer.offsetY, width: lowerPixels.width, height: lowerPixels.height)
        let bounds = Self.bounds(upper).map { below.union($0) } ?? below
        // Lower as a plain layer: its blend, opacity and mask stay on the layer.
        var plain = PhotoLayer(id: lower.layer.id, name: lower.layer.name)
        plain.offsetX = lower.layer.offsetX
        plain.offsetY = lower.layer.offsetY
        var merged = try Self.composite(
            LayerContent(layer: plain, pixels: lowerPixels), onto: TiledPixels(width: bounds.width, height: bounds.height),
            origin: (bounds.x, bounds.y))
        if upper.layer.isVisible && upper.layer.opacity > 0 {
            merged = try Self.composite(upper, onto: merged, origin: (bounds.x, bounds.y))
        }
        return PlacedPixels(pixels: merged, x: bounds.x, y: bounds.y)
    }

    func flatten(_ layers: [LayerContent], canvas: CanvasSize, adjustments: AdjustmentSettings) throws -> TiledPixels {
        var picture = try TiledPixels(width: canvas.width, height: canvas.height)
        for content in layers.reversed() where content.layer.isVisible && content.layer.opacity > 0 {
            picture = try Self.composite(content, onto: picture, origin: (0, 0))
        }
        guard adjustments.blurMargin == 0 else { return TiledPixels(try adjustments.applied(to: picture.flattened())) }
        // Every adjustment but the blur is per pixel, so it runs tile by tile.
        let tiles = picture.tiles
        picture.tiles = try PhotoLayerComposite.inParallel(tiles.count) { try adjustments.applied(to: tiles[$0]) }
        return picture
    }

    /// `content` through the renderer's per-layer step with the live services.
    private static func composite(
        _ content: LayerContent, onto below: TiledPixels, origin: (x: Int, y: Int)
    ) throws -> TiledPixels {
        try PhotoLayerComposite.composite(
            content, onto: below, origin: origin,
            adjusting: LiveAdjustmentLayers.make(), masking: LiveSelection.masking())
    }

    /// Where `content`'s pixels sit on the canvas; nil for an adjustment layer.
    static func bounds(_ content: LayerContent) -> PixelRect? {
        content.pixels.map {
            PixelRect(x: content.layer.offsetX, y: content.layer.offsetY, width: $0.width, height: $0.height)
        }
    }
}
