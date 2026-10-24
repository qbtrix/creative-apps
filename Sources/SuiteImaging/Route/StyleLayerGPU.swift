// StyleLayerGPU.swift: one styled layer drawn on the GPU (layer-styles HY-7).
// It keeps one RenderDispatcher on the backend's Metal device, the layer
// resident on it (StyleLayerResident: an upload only when the layer's content
// changes), and on each step runs StyleRoute.draw and writes the result into
// SuiteUI's presenter texture (sRGB, premultiplied, no readback). Until LS-9
// builds the draw it throws, and the resident layer is written unstyled.
// macOS only, inside `#if canImport(Metal)` (ImagingBoundaryTests).
#if canImport(Metal)
import CoreRaster
import CoreRender
import CoreRenderMetal
import Metal

public final class StyleLayerGPU {
    let backend: ImagingGPU.Backend
    let route: StyleRoute
    let resident: StyleLayerResident<AnyHashable>
    /// Layer uploads so far; a style-only step adds none.
    public var uploads: Int { resident.uploads }
    /// Steps that wrote the layer styled, and unstyled.
    public private(set) var styled = 0, unstyled = 0

    public init(_ backend: ImagingGPU.Backend) {
        let dispatcher = RenderDispatcher(preferred: backend.metal, fallback: CPUBackend())
        self.backend = backend
        route = StyleRoute(dispatcher: dispatcher)
        resident = StyleLayerResident(dispatcher: dispatcher)
    }

    /// The layer for `content` (`pixels`, linear premultiplied, read only
    /// when `content` is new) with `style` at `scale` into `texture` at its
    /// top left. `texture` is the layer's size, rgba8Unorm or bgra8Unorm with
    /// shaderWrite usage, on the backend's device. Throws what `pixels`, the
    /// upload or the display write throws.
    public func draw(content: AnyHashable, pixels: () throws -> PixelBuffer, style: LayerStyle?, scale: Double,
                     into texture: any MTLTexture) throws {
        let step = try resident.step(content: content, pixels: pixels, style: style) { style, layer in
            try route.draw(style, layer: layer, scale: scale)
        }
        defer { resident.finish(step) }
        let surface: RenderSurface
        switch step {
        case .styled(let s): (surface, styled) = (s, styled + 1)
        case .unstyled(let s): (surface, unstyled) = (s, unstyled + 1)
        }
        try backend.metal.display(surface, into: texture, x: 0, y: 0, colorSpace: .sRGB, premultiplied: true)
    }
}
#endif
