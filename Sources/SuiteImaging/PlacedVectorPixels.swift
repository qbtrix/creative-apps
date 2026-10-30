// PlacedVectorPixels.swift: a placed SVG (the kernel's `PlacedVector`) as pixels, the one CPU drawing of vector
// art every app shares. `fill` lays one item's contours, mapped through a caller's point map, on a premultiplied
// linear buffer: the contours are joined into one polygon by bridges back to each start (which cross twice and so
// cancel, keeping even-odd), drawn as CoreRaster's `Mask.polygon` in the item's colour. A gradient paints its
// middle colour, and strokes and text are not drawn. `pixels` draws a whole vector scaled into a width x height
// box, which is how Photo turns a placed SVG into a pixel layer. Halo's placed solids draw through `fill` too.
// Linux-safe.
import CoreRaster
import SuiteKernel

public enum PlacedVectorPixels {
    /// `item`'s fill over its contours, each point mapped by `map`, composited onto `out`. A nil fill paints nothing.
    public static func fill(_ item: PlacedVector.Item, map: (Point) -> Point, onto out: inout PixelBuffer) throws {
        guard let fill = item.fill else { return }
        let points = item.contours.flatMap { $0 + $0.prefix(1) }.map { p in
            let w = map(p)
            return Mask.Point(x: w.x, y: w.y)
        }
        // ponytail: a gradient paints its middle colour and strokes are skipped; draw both once art needs them.
        let c = GradientRules.color(of: fill, at: 0.5)
        guard points.count >= 3, let opaque = linear(c) else { return }
        let alpha = c.a * item.opacity
        let a = Float(alpha.isFinite ? min(max(alpha, 0), 1) : 1)
        let color = RGBA(r: opaque.r * a, g: opaque.g * a, b: opaque.b * a, a: a)
        let mask = try Mask.polygon(width: out.width, height: out.height, points: points)
        let paint = try PixelBuffer(width: out.width, height: out.height, fill: color)
        try out.composite(paint, x: 0, y: 0, mode: .normal, opacity: 1, mask: mask, maskX: 0, maskY: 0)
    }

    /// `vector` scaled to fill a clear `width` x `height` buffer; throws on a size of 0 or over the buffer limit.
    public static func pixels(_ vector: PlacedVector, width: Int, height: Int) throws -> PixelBuffer {
        var out = try PixelBuffer(width: width, height: height)
        guard vector.size.width > 0, vector.size.height > 0 else { return out }
        let sx = Double(width) / vector.size.width, sy = Double(height) / vector.size.height
        for item in vector.items { try fill(item, map: { Point(x: $0.x * sx, y: $0.y * sy) }, onto: &out) }
        return out
    }

    /// `color`'s red, green and blue (sRGB) as an opaque linear pixel; nil when a byte round trip fails.
    static func linear(_ color: FillColor) -> RGBA? {
        let bytes = [color.r, color.g, color.b].map { UInt8((($0.isNaN ? 0 : min(max($0, 0), 1)) * 255).rounded()) } + [255]
        return try? PixelBuffer(rgba8: bytes, width: 1, height: 1).pixel(x: 0, y: 0)
    }
}
