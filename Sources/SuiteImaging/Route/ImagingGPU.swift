// ImagingGPU.swift: the GPU entry points apps call (suite-imaging IM-16).
// `systemBackend()` is the system device's backend, its pipelines compiling in
// the background (nil means the CPU route); `display(_:into:program:displaySteps:)`
// writes a resident picture into SuiteUI's presenter texture with the tone
// program and the screen's display step (`ImagingColor.displaySteps`, last) in
// one `display_tone` pass, as MetalBackend.display(_:into:...tone:) runs it.
// The backend is opaque: apps hold an `ImagingGPU.Backend` and never name
// MetalBackend or cast to it. The texture and device are the system's own
// types the presenter already trades in. macOS only, inside
// `#if canImport(Metal)` (ImagingBoundaryTests).
#if canImport(Metal)
import CoreRaster
import CoreRender
import CoreRenderMetal
import Metal

public enum ImagingGPU {
    /// A GPU backend, opaque to apps.
    public final class Backend: Sendable {
        let metal: MetalBackend

        init(_ metal: MetalBackend) { self.metal = metal }

        /// The device its textures must live on (SuiteUI's presenter asks for it).
        public var device: any MTLDevice { metal.device }
        /// The same backend for a route that draws through CoreRender's protocol.
        public var renderBackend: any RenderBackend { metal }
        /// False once the GPU failed; the route then draws on the CPU.
        public var isHealthy: Bool { metal.isHealthy }
        /// True once its display pipelines have compiled, so `display` can run.
        public var isReady: Bool { metal.supports.contains(.display) }

        /// `buffer` uploaded once and kept on the GPU until the surface goes.
        /// Throws what the upload throws.
        public func upload(_ buffer: PixelBuffer) throws -> Surface {
            Surface(backend: self, picture: try metal.surface(buffer))
        }
    }

    /// One picture resident on a backend.
    public final class Surface {
        let backend: Backend
        let picture: RenderSurface
        /// Display writes so far.
        public private(set) var writes = 0

        init(backend: Backend, picture: RenderSurface) {
            self.backend = backend
            self.picture = picture
        }

        deinit { backend.metal.release(picture) }

        func wrote() { writes += 1 }
    }

    /// The Metal backend on the system GPU, its pipelines compiling in the
    /// background (`isReady` once they land); nil without a GPU, which means
    /// the CPU route.
    public static func systemBackend() -> Backend? {
        guard let device = MetalBackend.defaultDevice,
              let metal = try? MetalBackend.startingInBackground(device: device, cacheURL: nil) else { return nil }
        return Backend(metal)
    }

    /// The program the write runs: `program`, then the display step last.
    static func operations(_ program: [ToneProgram.Operation], _ displaySteps: ImagingDisplaySteps) -> [ToneProgram.Operation] {
        program + displaySteps.gpu
    }

    /// `surface` through `program` and then `displaySteps` into `texture`
    /// with its top-left pixel at (`x`, `y`): one display write (sRGB,
    /// premultiplied), no upload, no readback. `texture` is an rgba8Unorm or
    /// bgra8Unorm texture on the surface's device with shaderWrite usage.
    /// Throws what `ToneProgram(operations:)` or the write throws.
    public static func display(_ surface: Surface, into texture: any MTLTexture, program: [ToneProgram.Operation],
                               displaySteps: ImagingDisplaySteps, x: Int = 0, y: Int = 0) throws {
        let tone = try ToneProgram(operations: operations(program, displaySteps))
        try surface.backend.metal.display(surface.picture, into: texture, x: x, y: y, colorSpace: .sRGB,
                                          premultiplied: true, tone: tone)
        surface.wrote()
    }

    /// The live tone surface's tiles in `region` through `program` and then
    /// `displaySteps` (with `unsharp` from its cache) into `texture`: one
    /// display write per tile. Throws what `LiveToneSurface.draw` throws.
    public static func display(_ live: LiveToneSurface, into texture: any MTLTexture, program: [ToneProgram.Operation],
                               displaySteps: ImagingDisplaySteps, unsharp: LiveToneSurface.UnsharpParameters? = nil,
                               region: TileRect) throws {
        try live.draw(operations(program, displaySteps), unsharp: unsharp, into: texture, region: region)
    }
}
#endif
