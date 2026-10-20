// PhotoLayerPreview.swift (#3288): a pixel layer's small preview for its
// Layers row, its longest side at most the size asked for and its shape the
// layer's. Each preview pixel is the layer pixel at the centre of the box it
// covers, read straight from the tiles, so a preview costs a few hundred
// reads, never a full-size decode. The panel asks again only when an edit
// commits, not per stroke sample (PhotoLayerList). An adjustment layer has
// no pixels and no preview. Linux-safe.
import CoreRaster

extension PhotoWorkspace {
    /// Layer `id`'s preview, at most `longestSide` pixels on its longer side; nil for an adjustment
    /// layer, an unknown id or a size under 1.
    public func layerPreview(_ id: PhotoLayer.ID, longestSide: Int) -> DecodedImage? {
        // ponytail: nearest sampling, not a box filter; fine at row size, use TiledPixels.thumbnail's filter if previews alias.
        guard longestSide >= 1, let tiled = pixels[id], tiled.width >= 1, tiled.height >= 1 else { return nil }
        let longest = max(tiled.width, tiled.height), side = min(longestSide, longest)
        let w = max(1, tiled.width * side / longest), h = max(1, tiled.height * side / longest)
        guard var small = try? PixelBuffer(width: w, height: h) else { return nil }
        for y in 0..<h {
            for x in 0..<w {
                let sx = (2 * x + 1) * tiled.width / (2 * w), sy = (2 * y + 1) * tiled.height / (2 * h)
                guard let pixel = try? tiled.pixel(x: sx, y: sy), (try? small.setPixel(x: x, y: y, pixel)) != nil else { return nil }
            }
        }
        return (try? small.rgba8()).map { DecodedImage(rgba8: $0, width: w, height: h) }
    }
}
