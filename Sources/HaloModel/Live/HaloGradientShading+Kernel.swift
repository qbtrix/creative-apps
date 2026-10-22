// Live/HaloGradientShading+Kernel.swift (gradient-fill HG-6): the adapter onto
// SuiteKernel's Fill and GradientRules that gives a draw item's
// gradient as the color under each output pixel. The pixel's center maps
// back through the item's matrix into its bounds, then into the unit box the
// gradient's points are in; its offset there is the projection onto a linear
// gradient's line or the distance from a radial's center over its radius,
// clamped to 0...1. Colors come from a table of the gradient's sRGB stops
// decoded once to linear premultiplied light. Linux-safe.
import CoreRaster
import SuiteKernel

struct HaloGradientShading {
    /// Samples across 0...1; one decode of this many colors per item.
    static let steps = 1024

    let fill: Fill
    let inverse: HaloMatrix
    let bounds: HaloLayerRect
    let scaleX: Double, scaleY: Double
    let table: [RGBA]

    /// `item`'s gradient at an output scale; nil without a gradient, with a
    /// matrix that can't be inverted, an empty box or a refused decode.
    init?(_ item: HaloDrawItem, scaleX: Double, scaleY: Double) {
        guard let fill = item.gradient, GradientRules.type(of: fill) != .solid,
              let inverse = try? item.matrix.inverted(),
              item.bounds.width > 0, item.bounds.height > 0, scaleX > 0, scaleY > 0
        else { return nil }
        let last = Double(Self.steps - 1)
        let bytes = (0..<Self.steps).flatMap { i -> [UInt8] in
            let c = GradientRules.color(of: fill, at: Double(i) / last)
            return [c.r, c.g, c.b, c.a].map { UInt8((($0.isNaN ? 0 : min(max($0, 0), 1)) * 255).rounded()) }
        }
        guard let decoded = try? PixelBuffer(rgba8: bytes, width: Self.steps, height: 1) else { return nil }
        table = (0..<Self.steps).compactMap { try? decoded.pixel(x: $0, y: 0) }
        guard table.count == Self.steps else { return nil }
        (self.fill, self.inverse, self.bounds, self.scaleX, self.scaleY) = (fill, inverse, item.bounds, scaleX, scaleY)
    }

    /// The linear premultiplied color at output pixel (`x`, `y`)'s center.
    func color(x: Int, y: Int) -> RGBA {
        let layer = inverse.apply(HaloPoint(x: (Double(x) + 0.5) / scaleX, y: (Double(y) + 0.5) / scaleY))
        let u = HaloPoint(x: (layer.x - bounds.x) / bounds.width, y: (layer.y - bounds.y) / bounds.height)
        let t = Self.offset(of: fill, at: u)
        let index = Int((t * Double(Self.steps - 1)).rounded())
        return table[min(max(index, 0), Self.steps - 1)]
    }

    /// The gradient's offset at unit-box point `p`, clamped to 0...1; 0 for a
    /// solid, a line of no length, a radial of no radius or a non-finite value.
    static func offset(of fill: Fill, at p: HaloPoint) -> Double {
        let t: Double
        switch fill {
        case .solid: return 0
        case .linear(_, let start, let end):
            let (dx, dy) = (end.x - start.x, end.y - start.y)
            let length = dx * dx + dy * dy
            guard length > 0 else { return 0 }
            t = ((p.x - start.x) * dx + (p.y - start.y) * dy) / length
        case .radial(_, let center, let radius):
            guard radius > 0 else { return 0 }
            let (dx, dy) = (p.x - center.x, p.y - center.y)
            t = (dx * dx + dy * dy).squareRoot() / radius
        }
        return t.isFinite ? min(max(t, 0), 1) : 0
    }
}
