// ImagingGPU+Target.swift: where a resident render writes (suite-imaging IM-8,
// slice IM-photo). `backend(_:)` finds the GPU backend behind a route's
// CoreRender backend, so an app never casts to MetalBackend; a `Target` is
// SuiteUI's presenter texture on that backend, and `write` puts a resident
// surface into it at a pixel offset, through a tone program when one is
// given: one display write (sRGB, premultiplied), no readback. Apps hold the
// target and never name the texture type, so they import no Metal. macOS
// only, inside `#if canImport(Metal)` (ImagingBoundaryTests).
#if canImport(Metal)
import CoreRender
import CoreRenderMetal
import Metal

extension ImagingGPU {
    /// The GPU backend behind `backend`; nil for any other, as the CPU.
    public static func backend(_ backend: any RenderBackend) -> Backend? {
        guard let metal = backend as? MetalBackend else { return nil }
        return Backend(metal)
    }

    /// A texture a resident render writes the picture into, on a backend.
    /// Metal textures are safe to use from any thread; the type just isn't Sendable.
    public struct Target: @unchecked Sendable {
        let backend: Backend
        let texture: any MTLTexture

        /// `texture` (rgba8Unorm or bgra8Unorm, shaderWrite, on `backend.device`) written through `backend`.
        public init(_ texture: any MTLTexture, on backend: Backend) {
            self.backend = backend
            self.texture = texture
        }

        /// Which texture: a different one holds none of the picture yet.
        public var id: ObjectIdentifier { ObjectIdentifier(texture) }

        /// `surface` with its top-left pixel at (`x`, `y`), through `tone` when given: one display write.
        /// Throws what the write throws.
        public func write(_ surface: RenderSurface, x: Int, y: Int, tone: ToneProgram? = nil) throws {
            try backend.metal.display(surface, into: texture, x: x, y: y, colorSpace: .sRGB, premultiplied: true,
                                      tone: tone)
        }
    }
}
#endif
