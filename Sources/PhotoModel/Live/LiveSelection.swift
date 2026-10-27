// Live/LiveSelection.swift: the live selection shapes (a NotBuilt stand-in
// until PV-5) and the live layer masks. A mask is the size of its layer's
// pixels, opaque gray (r = g = b = coverage 0...1); masking multiplies every
// premultiplied channel of a layer pixel by the gray under it, so black hides
// and white leaves the pixel bit for bit. A pixel the mask doesn't reach is
// left as it is. Linux-safe.
import CoreRaster

enum LiveSelection {
    static func selection() -> any SelectionShaping { NotBuiltSelection() }
    static func masking() -> any LayerMasking { LiveMasking() }
}

struct LiveMasking: LayerMasking {
    var unavailableHelp: String? { nil }

    func mask(from selection: Mask?, layerBounds: PixelRect) throws -> TiledPixels {
        let (w, h) = (layerBounds.width, layerBounds.height)
        guard let selection else { return try TiledPixels(width: w, height: h, fill: RGBA(r: 1, g: 1, b: 1, a: 1)) }
        var gray = try PixelBuffer(width: w, height: h, fill: RGBA(r: 0, g: 0, b: 0, a: 1))
        for y in 0..<h {
            for x in 0..<w {
                let (cx, cy) = (layerBounds.x + x, layerBounds.y + y)
                guard (0..<selection.width).contains(cx), (0..<selection.height).contains(cy) else { continue }
                let c = try selection.coverage(x: cx, y: cy)
                if c > 0 { try gray.setPixel(x: x, y: y, RGBA(r: c, g: c, b: c, a: 1)) }
            }
        }
        return TiledPixels(gray)
    }

    func applying(_ mask: TiledPixels, to pixels: TiledPixels) throws -> TiledPixels {
        guard mask.width == pixels.width, mask.height == pixels.height else {
            throw RasterError.invalid("the mask is \(mask.width) x \(mask.height), the layer \(pixels.width) x \(pixels.height)")
        }
        var out = pixels
        for i in out.tiles.indices {
            let r = out.tileRect(i)
            out.tiles[i] = try masked(out.tiles[i], at: (r.x, r.y), by: mask)
        }
        return out
    }

    // ponytail: per-pixel reads, about a millisecond a 256 px tile; a row-wise multiply if masked layers profile slow.
    func masked(_ region: PixelBuffer, at origin: (x: Int, y: Int), by mask: TiledPixels) throws -> PixelBuffer {
        var out = region
        for y in 0..<region.height {
            let my = origin.y + y
            guard (0..<mask.height).contains(my) else { continue }
            for x in 0..<region.width {
                let mx = origin.x + x
                guard (0..<mask.width).contains(mx) else { continue }
                let g = try mask.pixel(x: mx, y: my).r
                guard g < 1 else { continue }
                let p = try region.pixel(x: x, y: y), k = max(g, 0)
                try out.setPixel(x: x, y: y, RGBA(r: p.r * k, g: p.g * k, b: p.b * k, a: p.a * k))
            }
        }
        return out
    }
}
