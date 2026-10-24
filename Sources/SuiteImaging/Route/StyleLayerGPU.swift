// StyleLayerGPU.swift (layer-styles HY-7): one styled layer on the GPU. One RenderDispatcher on the backend's
// device keeps the layer resident (StyleLayerResident); each step runs StyleRoute.draw and writes the result into
// SuiteUI's presenter texture (sRGB, premultiplied, no readback). macOS only (ImagingBoundaryTests).
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
        (self.backend, route, resident) = (backend, StyleRoute(dispatcher: dispatcher), StyleLayerResident(dispatcher: dispatcher))
    }
    /// The layer for `content` (`pixels`, linear premultiplied, read only when `content` is new) with `style`
    /// at `scale` into `texture` (the layer's size, shader-writable, on the backend's device) at its top left.
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
