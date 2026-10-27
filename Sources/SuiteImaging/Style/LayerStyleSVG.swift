// LayerStyleSVG.swift (layer-styles LS-1 stub, LS-7 body): a layer style as one SVG `<filter>`
// of W3C Filter Effects Level 1 primitives, with a warning for each style written approximately
// or not at all. Linux-safe.
import SuiteKernel

public enum LayerStyleSVG {
    /// A `<filter>` for `style` on a shape whose box is `box`, and the styles it wrote approximately or not at all.
    /// Stub: nothing and no warnings until LS-7.
    public static func filter(_ style: LayerStyle, id: String, box: Rect) -> (svg: String, warnings: [String]) { ("", []) }
}
