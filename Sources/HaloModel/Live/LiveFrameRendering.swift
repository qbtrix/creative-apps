// Live/LiveFrameRendering.swift: the live FrameRendering (#451, #457). Each
// solid (its rectangle) and shape (its ellipse) covers what VP-4a's
// HaloOutlines gives at its matrix: CoreRaster's exact Mask.rectangle /
// Mask.ellipse when the matrix only translates and scales up, Mask.polygon of
// the flattened outline otherwise. Its source is the linear premultiplied
// color times that coverage, composited bottom first with the item's blend
// mode and opacity. An outline, mask or composite that fails draws nothing
// and isn't counted. A text item (VP-5) is its TextRasterizing raster, top
// left on bounds.origin (so its baseline sits at height - descent), resized by
// HaloTextPlacement's scale, turned by its degrees about its center and
// composited at its world center; with no rasterizer, a mirror or any refusal
// it is skipped and counted. Nulls are never in the list, so they never
// count. Linux-safe.
import CoreRaster

public struct LiveFrameRendering: FrameRendering {
    public init() {}
    public var unavailableHelp: String? { nil }

    public func render(_ list: HaloDrawList, width: Int, height: Int, text: (any TextRasterizing)?) throws -> HaloRenderedFrame {
        var out = try PixelBuffer(width: width, height: height)
        let sx = Double(width) / Double(max(1, list.width)), sy = Double(height) / Double(max(1, list.height))
        var skipped = 0
        for item in list.items {
            let source: PixelBuffer?
            switch item.kind {
            case .solid, .shape:
                source = Self.coverageFill(item, width: width, height: height, scaleX: sx, scaleY: sy)
            case .text:
                guard let next = Self.drawText(item, onto: out, rasterizer: text, scaleX: sx, scaleY: sy)
                else { skipped += 1; continue }
                out = next
                continue
            case .null:
                continue
            }
            guard let source,
                  let next = try? composite(source, onto: out, mode: item.blendMode, opacity: Float(item.opacity))
            else { continue }
            out = next
        }
        return HaloRenderedFrame(pixels: out, frame: list.frame, skippedLayerCount: skipped)
    }

    /// `out` with `item`'s text composited at its placement, or nil (skipped)
    /// with no rasterizer, a mirrored or non-finite matrix, or any refusal.
    static func drawText(
        _ item: HaloDrawItem, onto out: PixelBuffer, rasterizer: (any TextRasterizing)?,
        scaleX sx: Double, scaleY sy: Double
    ) -> PixelBuffer? {
        guard let r = rasterizer, let p = HaloTextPlacement(item),
              var px = try? r.rasterize(item.text ?? HaloTextContent(), color: item.color),
              let w = whole(Double(px.width) * abs(p.scaleX) * sx),
              let h = whole(Double(px.height) * abs(p.scaleY) * sy)
        else { return nil }
        do {
            if w != px.width || h != px.height { px = try px.resized(width: w, height: h, filter: .bilinear) }
            px = try px.rotated(degrees: p.degrees, filter: .bilinear)
            guard let x = whole(p.center.x * sx - Double(px.width) / 2, allowsNegative: true),
                  let y = whole(p.center.y * sy - Double(px.height) / 2, allowsNegative: true)
            else { return nil }
            return try composite(px, onto: out, x: x, y: y, mode: item.blendMode, opacity: Float(item.opacity))
        } catch {
            return nil
        }
    }

    /// `value` rounded to an Int, or nil when it is not finite or too large to
    /// convert safely (and, unless `allowsNegative`, below zero).
    static func whole(_ value: Double, allowsNegative: Bool = false) -> Int? {
        let v = value.rounded()
        guard v.isFinite, abs(v) < 1_000_000_000, allowsNegative || v >= 0 else { return nil }
        return Int(v)
    }

    /// A `width` × `height` buffer of `item`'s color times its outline's
    /// coverage, premultiplied; nil when the outline or its mask is refused.
    static func coverageFill(
        _ item: HaloDrawItem, width: Int, height: Int, scaleX sx: Double, scaleY sy: Double
    ) -> PixelBuffer? {
        guard let color = item.color.linearPixel(),
              let outline = HaloOutlines.outline(of: item, scale: max(sx, sy)),
              let mask = try? outline.mask(width: width, height: height, scaleX: sx, scaleY: sy),
              var buffer = try? PixelBuffer(width: width, height: height)
        else { return nil }
        for y in 0..<height {
            for x in 0..<width {
                guard let c = try? mask.coverage(x: x, y: y), c > 0 else { continue }
                try? buffer.setPixel(x: x, y: y, RGBA(r: color.r * c, g: color.g * c, b: color.b * c, a: color.a * c))
            }
        }
        return buffer
    }
}
