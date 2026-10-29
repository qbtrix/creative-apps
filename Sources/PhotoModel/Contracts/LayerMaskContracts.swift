// Contracts/LayerMaskContracts.swift: layer masks (PV-5, #421). A layer mask
// is a buffer the layer's size whose gray (red channel) is the coverage, alpha
// always 1, so the brush paints black to hide and white to reveal and tile
// undo keeps its tiles (PhotoHistory's mask-tiles step). The selection it is
// made from is the kernel's area recipe, masked by SuiteImaging
// (PhotoArea+Kernel.swift). Linux-safe.
import CoreRaster

/// PV-5: layer masks.
public protocol LayerMasking: PhotoUseCase {
    /// A mask for a layer at `layerBounds` (canvas pixels): the selection's
    /// coverage as gray where it overlaps, black elsewhere; all white (reveal all) when
    /// `selection` is nil.
    func mask(from selection: Mask?, layerBounds: PixelRect) throws -> TiledPixels
    /// `pixels` with every alpha multiplied by the mask's gray: Apply Mask.
    func applying(_ mask: TiledPixels, to pixels: TiledPixels) throws -> TiledPixels
    /// `region`, a part of the layer at `origin` in layer pixels, multiplied
    /// by the mask there: what the renderer composites. Equals `region` for
    /// an all-1 mask, bit for bit.
    func masked(_ region: PixelBuffer, at origin: (x: Int, y: Int), by mask: TiledPixels) throws -> PixelBuffer
}
