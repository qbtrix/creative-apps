// Live/LiveFrameRendering.swift: the live FrameRendering (#451, #457). Each
// solid (its rectangle) and shape (its ellipse) covers what VP-4a's
// HaloOutlines gives at its matrix: CoreRaster's exact Mask.rectangle /
// Mask.ellipse when the matrix only translates and scales up, Mask.polygon of
// the flattened outline otherwise. Its source is the linear premultiplied
// color, or its gradient's color at each pixel (HG-6), times that coverage,
// composited bottom first with the item's blend mode and opacity. A solid
// with a placed picture (PH-5) takes HaloPlacedDrawing's pixels in place of
// its color, times the same coverage. A shape's
// stroke (HK-5) is then its outline polygon from HaloOutlines in the stroke's
// color, with the same blend and opacity. An outline, mask or composite that fails draws nothing
// and isn't counted. A text item (VP-5) is its TextRasterizing raster, top
// left on bounds.origin (so its baseline sits at height - descent), resized by
// HaloTextPlacement's scale, turned by its degrees about its center and
// composited at its world center; with no rasterizer, a mirror or any refusal
// it is skipped and counted. A layer with visible filters (AJ-12) is first
// drawn flat on a clear buffer, run through its list in order, then blended
// once. A styled solid or shape (layer-styles HY-6) merges its fill and
// stroke (after its filters), draws them through SuiteImaging's
// StyleProgram with the style's numbers sampled at the frame, and composites
// the result at the origin the program pads it to; when the program refuses
// it draws unstyled. Nulls are never in the list, so they never count.
// Linux-safe.
import CoreRaster
import SuiteImaging

public struct LiveFrameRendering: FrameRendering {
    public init() {}
    public var unavailableHelp: String? { nil }

    public func render(_ list: HaloDrawList, width: Int, height: Int, text: (any TextRasterizing)?) throws -> HaloRenderedFrame {
        var out = try PixelBuffer(width: width, height: height)
        let sx = Double(width) / Double(max(1, list.width)), sy = Double(height) / Double(max(1, list.height))
        var skipped = 0
        for item in list.items {
            let steps = item.filters.filter { !$0.hidden }
            var parts: [PixelBuffer]
            switch item.kind {
            case .solid, .shape:
                parts = [Self.placedFill(item, width: width, height: height, scaleX: sx, scaleY: sy)
                    ?? Self.coverageFill(item, width: width, height: height, scaleX: sx, scaleY: sy),
                         Self.strokeFill(item, width: width, height: height, scaleX: sx, scaleY: sy)].compactMap { $0 }
            case .text where steps.isEmpty:
                guard let next = Self.drawText(item, onto: out, rasterizer: text, scaleX: sx, scaleY: sy)
                else { skipped += 1; continue }
                out = next
                continue
            case .text:
                // A filtered text layer draws flat on its own buffer first, so the list sees only its pixels.
                var flat = item
                (flat.blendMode, flat.opacity) = (.normal, 1)
                guard let clear = try? PixelBuffer(width: width, height: height),
                      let drawn = Self.drawText(flat, onto: clear, rasterizer: text, scaleX: sx, scaleY: sy)
                else { skipped += 1; continue }
                parts = [drawn]
            case .null:
                continue
            }
            if !steps.isEmpty { parts = Self.filtered(parts, steps, width: width, height: height, scale: (sx + sy) / 2) }
            if item.kind != .text, let style = item.style,
               let styled = Self.styled(parts, style, width: width, height: height, scale: max(sx, sy)),
               let next = try? composite(styled.pixels, onto: out, x: styled.x, y: styled.y, mode: item.blendMode, opacity: Float(item.opacity)) {
                out = next
                continue
            }
            for layer in parts {
                guard let next = try? composite(layer, onto: out, mode: item.blendMode, opacity: Float(item.opacity))
                else { continue }
                out = next
            }
        }
        return HaloRenderedFrame(pixels: out, frame: list.frame, skippedLayerCount: skipped)
    }

    /// `parts` merged flat onto one clear layer and run through `steps` in order (AJ-12), so the list works on
    /// this layer's pixels alone and the blend comes after; nothing when a step is refused.
    static func filtered(
        _ parts: [PixelBuffer], _ steps: [HaloLayerFilter], width: Int, height: Int, scale: Double
    ) -> [PixelBuffer] {
        guard var layer = try? PixelBuffer(width: width, height: height) else { return [] }
        for part in parts {
            guard let next = try? composite(part, onto: layer, mode: .normal, opacity: 1) else { return [] }
            layer = next
        }
        guard let done = try? HaloLayerFilter.run(steps, on: layer, scale: scale) else { return [] }
        return [done]
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

    /// `layers` merged into one `width` × `height` buffer and drawn with
    /// `style` by StyleProgram, padded by its reach × `scale`, and where its
    /// top left sits; nil for an empty style or when the program refuses.
    static func styled(
        _ layers: [PixelBuffer?], _ style: LayerStyle, width: Int, height: Int, scale: Double
    ) -> (pixels: PixelBuffer, x: Int, y: Int)? {
        guard style != .none, var merged = try? PixelBuffer(width: width, height: height) else { return nil }
        for layer in layers {
            if let layer, let next = try? composite(layer, onto: merged, mode: .normal, opacity: 1) { merged = next }
        }
        guard let (pixels, origin) = try? StyleProgram.render(style, layer: merged, scale: scale) else { return nil }
        return (pixels, origin.x, origin.y)
    }

    /// `value` rounded to an Int, or nil when it is not finite or too large to
    /// convert safely (and, unless `allowsNegative`, below zero).
    static func whole(_ value: Double, allowsNegative: Bool = false) -> Int? {
        let v = value.rounded()
        guard v.isFinite, abs(v) < 1_000_000_000, allowsNegative || v >= 0 else { return nil }
        return Int(v)
    }

    /// A `width` × `height` buffer of `item`'s color, or its gradient's color
    /// at each pixel (HG-6), times its outline's coverage, premultiplied; nil
    /// when the outline or its mask is refused.
    static func coverageFill(
        _ item: HaloDrawItem, width: Int, height: Int, scaleX sx: Double, scaleY sy: Double
    ) -> PixelBuffer? {
        let shading = HaloGradientShading(item, scaleX: sx, scaleY: sy)
        guard let solid = item.color.linearPixel(), let outline = HaloOutlines.outline(of: item, scale: max(sx, sy))
        else { return nil }
        return paint(outline, width: width, height: height, scaleX: sx, scaleY: sy) { x, y in
            shading?.color(x: x, y: y) ?? solid
        }
    }

    /// A solid's placed picture (PH-5) from HaloPlacedDrawing's shared cache,
    /// times its outline's coverage; nil, so the solid draws its color, with
    /// no picture, a refused outline or bytes that don't decode.
    static func placedFill(
        _ item: HaloDrawItem, width: Int, height: Int, scaleX sx: Double, scaleY sy: Double
    ) -> PixelBuffer? {
        guard item.kind == .solid, let asset = item.placedAsset, let image = item.placedImage,
              let outline = HaloOutlines.outline(of: item, scale: max(sx, sy)),
              let picture = try? HaloPlacedDrawing.shared.withLock({
                  try $0.source(asset, image, matrix: item.matrix, width: width, height: height, scaleX: sx, scaleY: sy)
              })
        else { return nil }
        return paint(outline, width: width, height: height, scaleX: sx, scaleY: sy) { x, y in
            (try? picture.pixel(x: x, y: y)) ?? .clear
        }
    }

    /// A `width` × `height` buffer of a shape's stroke color, premultiplied,
    /// over its stroke outline (HK-5); nil with no stroke or a refused outline.
    static func strokeFill(
        _ item: HaloDrawItem, width: Int, height: Int, scaleX sx: Double, scaleY sy: Double
    ) -> PixelBuffer? {
        guard let stroke = item.stroke,
              let opaque = HaloLayerColor(red: stroke.color.r, green: stroke.color.g, blue: stroke.color.b).linearPixel(),
              let outline = HaloOutlines.strokeOutline(of: item, scale: max(sx, sy))
        else { return nil }
        let a = Float(stroke.color.a.isFinite ? min(max(stroke.color.a, 0), 1) : 1)
        let color = RGBA(r: opaque.r * a, g: opaque.g * a, b: opaque.b * a, a: a)
        return paint(outline, width: width, height: height, scaleX: sx, scaleY: sy) { _, _ in color }
    }

    /// `color` at each pixel times `outline`'s coverage, premultiplied; nil
    /// when the mask or buffer is refused.
    static func paint(
        _ outline: HaloOutline, width: Int, height: Int, scaleX sx: Double, scaleY sy: Double,
        color: (Int, Int) -> RGBA
    ) -> PixelBuffer? {
        guard var buffer = try? PixelBuffer(width: width, height: height),
              let coverage = coverage(outline, width: width, height: height, scaleX: sx, scaleY: sy)
        else { return nil }
        for y in 0..<height {
            for x in 0..<width {
                let c = coverage(x, y)
                guard c > 0 else { continue }
                let color = color(x, y)
                try? buffer.setPixel(x: x, y: y, RGBA(r: color.r * c, g: color.g * c, b: color.b * c, a: color.a * c))
            }
        }
        return buffer
    }

    /// `outline`'s coverage at a pixel: a polygon's from HaloScanline (the
    /// same samples as Mask.polygon, a row at a time, HK-5), a box's or
    /// ellipse's from CoreRaster's Mask; nil when refused or non-finite.
    static func coverage(
        _ outline: HaloOutline, width: Int, height: Int, scaleX sx: Double, scaleY sy: Double
    ) -> ((Int, Int) -> Float)? {
        if case .polygon(let points) = outline {
            let scaled = points.map { HaloPoint(x: $0.x * sx, y: $0.y * sy) }
            guard width > 0, height > 0, scaled.allSatisfy({ $0.x.isFinite && $0.y.isFinite }) else { return nil }
            let cells = HaloScanline.coverage(scaled, width: width, height: height)
            return { x, y in
                let i = y * width + x
                return x >= 0 && x < width && cells.indices.contains(i) ? cells[i] : 0
            }
        }
        guard let mask = try? outline.mask(width: width, height: height, scaleX: sx, scaleY: sy) else { return nil }
        return { x, y in (try? mask.coverage(x: x, y: y)) ?? 0 }
    }
}
