// LiveToneSurface.swift: one resident picture on the GPU (suite-imaging IM-2
// stub, IM-5 body). A tone step folds its program into the display write: no
// composite, no readback. macOS only, inside `#if canImport(Metal)`; the only
// Metal file outside SuiteUI's canvas host besides its Route/ siblings
// (ImagingBoundaryTests). Stub: `init` and `draw` throw `notBuilt`.
//
// The base is CoreRaster's PixelBuffer: the contract's TiledPixels is
// PhotoModel's type, which SuiteImaging can't import; IM-5 settles the tiled
// base type when it lifts PhotoLiveTone.
#if canImport(Metal)
import CoreRaster
import CoreRender
import Metal

public final class LiveToneSurface {
    /// tone-controls' `ToneRules.unsharp`: run once over the base and cached
    /// until the base or these change.
    public struct UnsharpParameters: Hashable, Sendable {
        public var amount, sigma, threshold: Double

        public init(amount: Double, sigma: Double, threshold: Double) {
            self.amount = amount
            self.sigma = sigma
            self.threshold = threshold
        }
    }

    /// `base` uploaded to `device` and kept resident. Stub: throws `notBuilt`.
    public init(device: any MTLDevice, base: PixelBuffer) throws {
        throw ImagingError.notBuilt("LiveToneSurface waits on IM-5")
    }

    /// A pixel edit: re-uploads only the `damaged` tiles. Tone steps never
    /// call it. Stub: does nothing.
    public func replaceBase(_ base: PixelBuffer, damaged: [TileRect]) {}

    /// `program` over the resident base, with `unsharp` from its cache, into
    /// `region` of `target`. Stub: throws `notBuilt`.
    public func draw(_ program: [ToneProgram.Operation], unsharp: UnsharpParameters?, into target: any MTLTexture,
                     region: TileRect) throws {
        throw ImagingError.notBuilt("LiveToneSurface.draw waits on IM-5")
    }
}
#endif
