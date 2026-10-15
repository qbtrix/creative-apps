// Live/LiveFrameRendering.swift: the live FrameRendering (#451, #457). Each
// solid (its rectangle) and shape (its ellipse) covers what VP-4a's
// HaloOutlines gives at its matrix: CoreRaster's exact Mask.rectangle /
// Mask.ellipse when the matrix only translates and scales up, Mask.polygon of
// the flattened outline otherwise. Its source is the linear premultiplied
// color times that coverage, composited bottom first with the item's blend
// mode and opacity. An outline, mask or composite that fails draws nothing
// and isn't counted. Text items are counted as skipped until VP-5 draws them
// here; nulls are never in the list, so they never count. Linux-safe.
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
                // VP-5 seam: text pixels (TextRasterizing, HaloTextPlacement) go
                // here; until then every text item is skipped and counted.
                skipped += 1
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
