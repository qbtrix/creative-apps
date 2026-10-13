// FrameRenderer.swift: renders one frame of a Halo composition with
// CoreRaster's compositor, the first engine flow until Halo's own composition
// engine lands in creative-core. Each solid visible at the frame becomes a
// frame-size buffer (its color times its rectangle's coverage, premultiplied),
// and layers composite bottom to top with their blend mode and opacity. Other
// layer kinds don't render yet; the result counts them so the viewer can say
// so. Linux-safe: no UI imports. The viewer shows `pixels` through CoreRaster's
// `rgba8(colorSpace:)`.
import CoreRaster

/// One rendered frame of a composition.
public struct HaloRenderedFrame: Sendable, Equatable {
    /// The frame, linear light, premultiplied, at the render size.
    public let pixels: PixelBuffer
    /// The frame number it shows.
    public let frame: Int
    /// Layers visible at the frame that were left out because only solids render.
    public let skippedLayerCount: Int

    /// The viewer's note about skipped layers; nil when nothing was skipped.
    public var note: String? {
        switch skippedLayerCount {
        case 0: nil
        case 1: "Only solids render for now; 1 layer skipped."
        default: "Only solids render for now; \(skippedLayerCount) layers skipped."
        }
    }
}

extension HaloComposition {
    /// The viewer renders at quarter size: 480 by 270 for 1080p.
    public static let previewScale = 4

    /// Renders `frame` at 1/`scale` size (at least 1 by 1 pixel). Nil when
    /// `scale` is below 1 or the size is one CoreRaster refuses.
    public func renderFrame(at frame: Int, scale: Int = previewScale) -> HaloRenderedFrame? {
        guard scale >= 1 else { return nil }
        let w = max(1, width / scale), h = max(1, height / scale)
        guard width > 0, height > 0, var result = try? PixelBuffer(width: w, height: h) else { return nil }
        var skipped = 0
        for layer in layers.reversed() where layer.isVisible(at: frame) {
            guard layer.kind == .solid else {
                skipped += 1
                continue
            }
            guard let source = solidBuffer(layer, width: w, height: h),
                let next = try? composite(source, onto: result, mode: layer.blendMode, opacity: Float(layer.opacity))
            else { continue }
            result = next
        }
        return HaloRenderedFrame(pixels: result, frame: frame, skippedLayerCount: skipped)
    }

    /// A `width` x `height` buffer of `layer`'s color over its rectangle,
    /// scaled from composition pixels; nil for a rectangle Mask refuses.
    private func solidBuffer(_ layer: HaloLayer, width w: Int, height h: Int) -> PixelBuffer? {
        guard let color = layer.color.linearPixel() else { return nil }
        guard let rect = layer.rect else { return try? PixelBuffer(width: w, height: h, fill: color) }
        let sx = Double(w) / Double(width), sy = Double(h) / Double(height)
        guard
            let mask = try? Mask.rectangle(
                width: w, height: h, x: rect.x * sx, y: rect.y * sy, w: rect.width * sx, h: rect.height * sy),
            var buffer = try? PixelBuffer(width: w, height: h)
        else { return nil }
        for y in 0..<h {
            for x in 0..<w {
                guard let c = try? mask.coverage(x: x, y: y), c > 0 else { continue }
                try? buffer.setPixel(x: x, y: y, RGBA(r: color.r * c, g: color.g * c, b: color.b * c, a: color.a * c))
            }
        }
        return buffer
    }
}

extension HaloLayerColor {
    /// The color as an opaque linear-light pixel, decoded from 8-bit sRGB by
    /// CoreRaster so the transfer curve isn't repeated here.
    func linearPixel() -> RGBA? {
        let bytes = [red, green, blue].map { UInt8((($0.isNaN ? 0 : min(max($0, 0), 1)) * 255).rounded()) } + [255]
        return try? PixelBuffer(rgba8: bytes, width: 1, height: 1).pixel(x: 0, y: 0)
    }
}

extension HaloProject {
    /// Renders the selected composition at `frame` at preview size; nil with
    /// no composition selected.
    public func renderSelectedFrame(at frame: Int) -> HaloRenderedFrame? {
        selectedComposition?.renderFrame(at: frame)
    }
}
