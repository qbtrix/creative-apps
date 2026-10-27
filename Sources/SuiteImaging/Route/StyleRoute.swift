// StyleRoute.swift (layer-styles LS-1 stub, LS-9 body): the live layer style on the GPU, one core `.style` op on a
// resident surface per step, no readback. macOS only, inside `#if canImport(Metal)` (ImagingBoundaryTests).
#if canImport(Metal)
import CoreRender

public final class StyleRoute {
    let dispatcher: RenderDispatcher
    public init(dispatcher: RenderDispatcher) { self.dispatcher = dispatcher }

    /// The styled layer, padded by `StyleRules.reach`, as a resident surface: one `.style` op on the GPU.
    /// Stub: throws until LS-9.
    public func draw(_ style: LayerStyle, layer: RenderSurface, scale: Double) throws -> RenderSurface {
        throw ImagingError.notBuilt("layer-styles LS-9")
    }
}
#endif
