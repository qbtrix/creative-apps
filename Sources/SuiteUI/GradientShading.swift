// GradientShading.swift (gradient-fill GF-2 stub, GF-3 body): the one bridge from the kernel's `Fill` to a SwiftUI
// shading, for every view that paints a fill (the gradient editor's bar and preview, Design's and Flare's canvases).
// sRGB, straight alpha, like `StageRasterizer`. A fill's points are in `box`'s space; `rect` is where the box is drawn.
// The stub paints the fill's first colour (a solid's own) until GF-3 maps the line or the centre into `rect`.
import SuiteKernel
import SwiftUI

extension Fill {
    /// This fill as a SwiftUI shading over `rect`, its points mapped from `box` to `rect`.
    /// Stub: the first stop's colour (a solid's own); GF-3 fills this in.
    public func shading(in rect: CGRect, box: Rect) -> GraphicsContext.Shading {
        .color(GradientRules.color(of: self, at: 0).swiftUI)
    }
}

extension FillColor {
    /// This colour as a SwiftUI colour: sRGB channels and straight alpha.
    var swiftUI: SwiftUI.Color {
        SwiftUI.Color(SwiftUI.Color.Resolved(red: Float(r), green: Float(g), blue: Float(b), opacity: Float(a)))
    }
}
