// GradientRules.swift (gradient-fill GF-1 stubs, GF-5 bodies): the stop, angle and box rules, once, so the vector
// path (canvas, SVG) and the raster path take their points from the same function. Angles are degrees, y down:
// 0 runs left to right, 90 top to bottom. Every stub below returns its input (or the neutral value it names)
// until GF-5 fills it in; only `type(of:)` is real.

public enum GradientRules {
    /// The most stops a gradient holds, and why a gradient can't drop below two.
    public static let maxStops = 64, stopHelp = "A gradient needs at least two stops."
    /// What a fill command's run throws until GF-6 builds the bodies.
    public static let notBuilt = CatalogError.notBuilt(id: "fill", feature: "gradient-fill GF-6")

    /// Which of the three fills `fill` is.
    public static func type(of fill: Fill) -> FillType {
        switch fill {
        case .solid: .solid
        case .linear: .linear
        case .radial: .radial
        }
    }
    /// `fill` as `type` in `box`: solid to linear is the colour to white at 0°, to radial the same stops about the
    /// centre out to half the diagonal; linear and radial keep their stops; to solid keeps the first colour.
    /// Stub: returns `fill`; GF-5 fills this in.
    public static func converted(_ fill: Fill, to type: FillType, in box: Rect) -> Fill { fill }
    /// A linear fill's angle in degrees, in [0, 360); nil for solid and radial. Stub: nil; GF-5 fills this in.
    public static func angle(of fill: Fill) -> Double? { nil }
    /// A linear fill's line turned to `degrees` about `box`'s centre, its ends where the box's corners project, so the
    /// corners land on 0 and 1; non-finite degrees leave it unchanged. Stub: returns `fill`; GF-5 fills this in.
    public static func rotated(_ fill: Fill, to degrees: Double, in box: Rect) -> Fill { fill }
    /// The colour at `offset`, clamped to the end stops, a straight sRGB lerp between two stops (the later of two at
    /// one offset wins there). Stub: the first stop's colour (a solid's own); GF-5 fills this in.
    public static func color(of fill: Fill, at offset: Double) -> FillColor {
        if case .solid(let color) = fill { return color }
        return fill.stops.first?.color ?? .black
    }
    /// `fill` with a stop at `offset` in the colour the gradient shows there, and its index; nil for a solid or a
    /// gradient at `maxStops`. Stub: nil; GF-5 fills this in.
    public static func addingStop(_ fill: Fill, at offset: Double) -> (fill: Fill, index: Int)? { nil }
    /// `fill` with stop `index` moved to `offset` clamped to 0...1, re-sorted stably, and the stop's new index.
    /// Stub: returns `fill` and `index`; GF-5 fills this in.
    public static func movingStop(_ fill: Fill, index: Int, to offset: Double) -> (fill: Fill, index: Int) { (fill, index) }
    /// `fill` without stop `index`; nil with two stops left. Stub: returns `fill`; GF-5 fills this in.
    public static func removingStop(_ fill: Fill, index: Int) -> Fill? { fill }
    /// `fill` with stop `index` (a solid's colour) set to `color`. Stub: returns `fill`; GF-5 fills this in.
    public static func recoloring(_ fill: Fill, index: Int, to color: FillColor) -> Fill { fill }
    /// `fill`'s points (and a radial's radius) mapped from the box `from` to the box `to`.
    /// Stub: returns `fill`; GF-5 fills this in.
    public static func mapped(_ fill: Fill, from: Rect, to: Rect) -> Fill { fill }
}
