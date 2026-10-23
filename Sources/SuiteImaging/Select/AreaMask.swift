// AreaMask.swift (area-selection AR-5 stub, AR-6 body): the kernel's area recipe as a CoreRaster mask. Each shape
// renders to its own mask and joins the area by its mode; invert, feather and expand apply where they sit in the
// list, so a feather before a subtract keeps the cut hard. The outline is the mask's contours at 0.5, for the
// marching ants. Linux-safe.
import CoreRaster
import SuiteKernel

/// An area recipe turned into coverage.
public enum AreaMask {
    /// The two pictures the magic wand can sample: the target layer, or the composite with All Layers.
    public struct Sources: Sendable {
        /// The target layer's pixels, canvas-sized.
        public var layer: PixelBuffer
        /// The flattened picture, canvas-sized.
        public var composite: PixelBuffer
        /// Both pictures, each the mask's size.
        public init(layer: PixelBuffer, composite: PixelBuffer) {
            (self.layer, self.composite) = (layer, composite)
        }
    }

    /// The coverage `recipe` selects on a `width` x `height` canvas. Throws for a size CoreRaster rejects, a wand
    /// step without `sources` or with sources of another size, or a feather radius CoreRaster refuses.
    public static func mask(_ recipe: AreaRecipe, width: Int, height: Int, sources: Sources?) throws -> Mask {
        try Mask(width: width, height: height)
    }

    /// The closed outlines where `mask`'s coverage crosses 0.5, in canvas pixels, for the ants.
    public static func outline(_ mask: Mask) throws -> [[Point]] {
        []
    }
}
