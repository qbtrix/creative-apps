// StyleProgram.swift (layer-styles LS-1 stubs, LS-8 bodies): the one mapping from a LayerStyle to core's
// LayerStyleStack and back (import's way in), and the CPU render padded by `StyleRules.reach`. Linux-safe.
import CoreRaster

public enum StyleProgram {
    /// Core's stack for `style`: linear premultiplied colours, core's angle convention, px × `scale`.
    /// Stub: an empty stack until LS-8.
    public static func stack(_ style: LayerStyle, scale: Double) -> LayerStyleStack { LayerStyleStack(entries: []) }

    /// The style a core stack holds, and the entries it can't (a second instance, satin, pattern).
    /// Stub: no style until LS-8.
    public static func style(_ stack: LayerStyleStack) -> (LayerStyle, dropped: [String]) { (.none, []) }

    /// `layer` drawn with `style` on the CPU, padded by reach × `scale`, and the new origin.
    /// Stub: throws until LS-8.
    public static func render(_ style: LayerStyle, layer: PixelBuffer, scale: Double) throws -> (PixelBuffer, origin: (x: Int, y: Int)) {
        throw ImagingError.notBuilt("layer-styles LS-8")
    }
}
