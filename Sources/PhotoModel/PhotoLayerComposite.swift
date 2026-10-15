// PhotoLayerComposite.swift: one layer's contribution to the picture under
// it, the per-layer step of the renderer and of LiveEdit's Merge Down and
// Flatten (photo-seams review note 2), so all three pick up adjustment layers
// and masks from one place. Today a pixel layer composites with its blend
// mode and opacity at its offset (CoreRaster's composite, tile by tile, each
// clipped to the region, exactly as the renderer always did); an adjustment
// layer gives back `below` unchanged until photo-adjustment-layers fills that
// case through `adjusting`; the mask is ignored until PV-5 fills it through
// `masking`. Whether a layer shows at all (hidden, opacity 0) is the caller's
// call. Linux-safe.
import CoreRaster

public enum PhotoLayerComposite {
    /// `content` composited onto `below`, a region of the canvas whose
    /// top-left pixel is canvas pixel `origin`. Only the layer's tiles under
    /// the region are visited. Throws `RasterError` when CoreRaster rejects
    /// the layer's opacity.
    public static func composite(_ content: LayerContent, onto below: PixelBuffer,
                                 origin: (x: Int, y: Int),
                                 adjusting: any AdjustmentLayering,
                                 masking: any LayerMasking) throws -> PixelBuffer {
        let layer = content.layer
        // ponytail: photo-adjustment-layers fills .adjustment with adjusting.applying, PV-5 masks with masking.masked.
        guard case .pixels = layer.kind, let tiled = content.pixels else { return below }
        let region = PixelRect(
            x: origin.x - layer.offsetX, y: origin.y - layer.offsetY, width: below.width, height: below.height)
        var picture = below
        for i in tiled.tileIndices(in: region) where tiled.tiles.indices.contains(i) {
            let tile = tiled.tileRect(i).offsetBy(layer.offsetX - origin.x, layer.offsetY - origin.y)
            picture = try CoreRaster.composite(
                tiled.tiles[i], onto: picture, x: tile.x, y: tile.y, mode: layer.blendMode,
                opacity: Float(layer.opacity))
        }
        return picture
    }
}
