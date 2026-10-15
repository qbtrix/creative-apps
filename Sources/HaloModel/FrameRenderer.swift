// FrameRenderer.swift: one rendered frame of a Halo composition and the thin
// wrappers that make it. A frame is a draw list (FrameDrawing) turned into
// pixels (FrameRendering): `renderFrame` uses the live pair, the project's
// `renderSelectedFrame` its own services. Solids and shapes draw at their
// matrix with blend mode and opacity (LiveFrameRendering); text layers the
// renderer couldn't draw are counted so the viewer can say so. Linux-safe:
// no UI imports. The viewer shows `pixels` through CoreRaster's
// `rgba8(colorSpace:)`.
import CoreRaster

/// One rendered frame of a composition.
public struct HaloRenderedFrame: Sendable, Equatable {
    /// The frame, linear light, premultiplied, at the render size.
    public let pixels: PixelBuffer
    /// The frame number it shows.
    public let frame: Int
    /// Text layers visible at the frame that the renderer couldn't draw.
    public let skippedLayerCount: Int

    /// The viewer's note about undrawn text; nil when nothing was skipped.
    public var note: String? {
        switch skippedLayerCount {
        case 0: nil
        case 1: "1 text layer not drawn."
        default: "\(skippedLayerCount) text layers not drawn."
        }
    }
}

extension HaloComposition {
    /// The viewer renders at quarter size: 480 by 270 for 1080p.
    public static let previewScale = 4

    /// Renders `frame` at 1/`scale` size (at least 1 by 1 pixel) with the live
    /// drawing and rendering; `text` draws text layers. Nil when `scale` is
    /// below 1 or the size is one CoreRaster refuses.
    public func renderFrame(
        at frame: Int, scale: Int = previewScale, text: (any TextRasterizing)? = nil
    ) -> HaloRenderedFrame? {
        renderFrame(at: frame, scale: scale, drawing: LiveFrameDrawing(), rendering: LiveFrameRendering(), text: text)
    }

    func renderFrame(
        at frame: Int, scale: Int, drawing: any FrameDrawing, rendering: any FrameRendering,
        text: (any TextRasterizing)?
    ) -> HaloRenderedFrame? {
        guard scale >= 1, width > 0, height > 0 else { return nil }
        let list = drawing.drawList(self, at: frame)
        return try? rendering.render(list, width: max(1, width / scale), height: max(1, height / scale), text: text)
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
    /// Renders the selected composition at `frame` at preview size over the
    /// project's drawing, rendering and text services; nil with no
    /// composition selected.
    public func renderSelectedFrame(at frame: Int) -> HaloRenderedFrame? {
        selectedComposition?.renderFrame(
            at: frame, scale: HaloComposition.previewScale, drawing: services.drawing,
            rendering: services.rendering, text: services.text)
    }
}
