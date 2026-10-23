// GradientShading.swift (gradient-fill GF-3): the one bridge from the kernel's `Fill` to a SwiftUI shading, for every
// view that paints a fill (the gradient editor's bar and preview, Design's and Flare's canvases). sRGB, straight
// alpha, like `StageRasterizer`. A fill's points are in `box`'s space; `rect` is where the box is drawn, and the
// points get there through `GradientRules.mapped`, the same mapping every other path uses (no second copy here).
import SuiteKernel
import SwiftUI

extension Fill {
    /// This fill as a SwiftUI shading over `rect`, its points (and a radial's radius) mapped from `box` to `rect`.
    public func shading(in rect: CGRect, box: Rect) -> GraphicsContext.Shading {
        let target = Rect(minX: Double(rect.minX), minY: Double(rect.minY), maxX: Double(rect.maxX), maxY: Double(rect.maxY))
        let gradient = SwiftUI.Gradient(stops: stops.map { .init(color: $0.color.swiftUI, location: CGFloat($0.offset)) })
        func point(_ p: Point) -> CGPoint { CGPoint(x: p.x, y: p.y) }
        switch GradientRules.mapped(self, from: box, to: target) {
        case .solid(let color):
            return .color(color.swiftUI)
        case .linear(_, let start, let end):
            return .linearGradient(gradient, startPoint: point(start), endPoint: point(end))
        case .radial(_, let center, let radius):
            return .radialGradient(gradient, center: point(center), startRadius: 0, endRadius: CGFloat(radius))
        }
    }
}

extension FillColor {
    /// This colour as a SwiftUI colour: sRGB channels and straight alpha.
    var swiftUI: SwiftUI.Color {
        SwiftUI.Color(SwiftUI.Color.Resolved(red: Float(r), green: Float(g), blue: Float(b), opacity: Float(a)))
    }
}
