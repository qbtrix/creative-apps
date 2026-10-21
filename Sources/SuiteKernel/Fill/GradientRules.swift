// GradientRules.swift (gradient-fill GF-5): the stop, angle and box rules, once, so the vector path (canvas, SVG) and
// the raster path take their points from the same function. Angles are degrees, y down: 0 runs left to right, 90 top
// to bottom. A linear line turns about its box's centre with its ends where the box's corners project, so the corners
// land on 0 and 1. Every rule returns a fill that keeps FlareCore's invariants: stops sorted in 0...1, a radial
// radius above 0. A rule that can't apply returns its input (or nil where it says so), never a broken fill.
#if canImport(Glibc)
import Glibc  // sin, cos, atan2
#elseif canImport(Musl)
import Musl
#elseif canImport(Darwin)
import Darwin
#endif

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
    public static func converted(_ fill: Fill, to type: FillType, in box: Rect) -> Fill {
        guard type != Self.type(of: fill) else { return fill }
        let stops = if case .solid(let color) = fill {
            [GradientStop(offset: 0, color: color), GradientStop(offset: 1, color: .white)]
        } else { fill.stops }
        let center = center(of: box)
        switch type {
        case .solid: return .solid(stops.first?.color ?? .black)
        case .linear: return rotated(.linear(stops: stops, start: center, end: center), to: 0, in: box)
        case .radial:
            // ponytail: a box with no diagonal still gets a 1-unit radius, so the fill stays valid.
            let radius = (box.width * box.width + box.height * box.height).squareRoot() / 2
            return .radial(stops: stops, center: center, radius: radius > 0 && radius.isFinite ? radius : 1)
        }
    }

    /// A linear fill's angle in degrees, in [0, 360); nil for solid and radial (0 for a line with no length).
    public static func angle(of fill: Fill) -> Double? {
        guard case .linear(_, let start, let end) = fill else { return nil }
        let (dx, dy) = (end.x - start.x, end.y - start.y)
        guard dx.isFinite, dy.isFinite, dx != 0 || dy != 0 else { return 0 }
        let degrees = atan2(dy, dx) * 180 / .pi
        let turned = degrees < 0 ? degrees + 360 : degrees
        return turned >= 360 ? 0 : turned
    }

    /// A linear fill's line turned to `degrees` about `box`'s centre, its ends where the box's corners project, so the
    /// corners land on 0 and 1; non-finite degrees, and a solid or radial fill, leave it unchanged.
    public static func rotated(_ fill: Fill, to degrees: Double, in box: Rect) -> Fill {
        guard case .linear(let stops, _, _) = fill, degrees.isFinite else { return fill }
        let (sine, cosine) = sinCos(degrees: degrees)
        let center = center(of: box)
        let half = (abs(box.width * cosine) + abs(box.height * sine)) / 2
        return .linear(stops: stops, start: Point(x: center.x - half * cosine, y: center.y - half * sine),
                       end: Point(x: center.x + half * cosine, y: center.y + half * sine))
    }

    /// The colour at `offset`, clamped to the end stops, a straight sRGB lerp between two stops (the later of two at
    /// one offset wins there); a solid's own colour.
    public static func color(of fill: Fill, at offset: Double) -> FillColor {
        if case .solid(let color) = fill { return color }
        let stops = fill.stops
        guard let index = stops.lastIndex(where: { $0.offset <= offset }) else { return stops.first?.color ?? .black }
        let (a, next) = (stops[index], index + 1)
        guard next < stops.count else { return a.color }
        let b = stops[next]
        let t = (offset - a.offset) / (b.offset - a.offset)
        func lerp(_ x: Double, _ y: Double) -> Double { x + (y - x) * t }
        return FillColor(r: lerp(a.color.r, b.color.r), g: lerp(a.color.g, b.color.g),
                         b: lerp(a.color.b, b.color.b), a: lerp(a.color.a, b.color.a))
    }

    /// `fill` with a stop at `offset` (clamped to 0...1) in the colour the gradient shows there, after any stop at
    /// that offset, and its index; nil for a solid, a non-finite offset or a gradient at `maxStops`.
    public static func addingStop(_ fill: Fill, at offset: Double) -> (fill: Fill, index: Int)? {
        guard type(of: fill) != .solid, offset.isFinite, fill.stops.count < maxStops else { return nil }
        let clamped = min(max(offset, 0), 1)
        var stops = fill.stops
        let index = stops.firstIndex { $0.offset > clamped } ?? stops.count
        stops.insert(GradientStop(offset: clamped, color: color(of: fill, at: clamped)), at: index)
        return (with(fill, stops: stops), index)
    }

    /// `fill` with stop `index` moved to `offset` clamped to 0...1, re-sorted stably, and the stop's new index. A bad
    /// index or a non-finite offset returns `fill` and `index` unchanged.
    public static func movingStop(_ fill: Fill, index: Int, to offset: Double) -> (fill: Fill, index: Int) {
        var stops = fill.stops
        guard stops.indices.contains(index), offset.isFinite else { return (fill, index) }
        stops[index].offset = min(max(offset, 0), 1)
        let order = stops.indices.sorted { (stops[$0].offset, $0) < (stops[$1].offset, $1) }
        return (with(fill, stops: order.map { stops[$0] }), order.firstIndex(of: index) ?? index)
    }

    /// `fill` without stop `index`; nil when it can't lose one: two stops left, a bad index or a solid.
    public static func removingStop(_ fill: Fill, index: Int) -> Fill? {
        var stops = fill.stops
        guard stops.indices.contains(index), stops.count > 2 else { return nil }
        stops.remove(at: index)
        return with(fill, stops: stops)
    }

    /// `fill` with stop `index` (a solid's colour) set to `color`; a bad index leaves it unchanged.
    public static func recoloring(_ fill: Fill, index: Int, to color: FillColor) -> Fill {
        if case .solid = fill { return .solid(color) }
        var stops = fill.stops
        guard stops.indices.contains(index) else { return fill }
        stops[index].color = color
        return with(fill, stops: stops)
    }

    /// `fill`'s points mapped from the box `from` to the box `to`, a radial's radius scaled by the mean of the two
    /// scales (the square root of their product). A box with no width or height leaves it unchanged.
    public static func mapped(_ fill: Fill, from: Rect, to: Rect) -> Fill {
        let (sx, sy) = (to.width / from.width, to.height / from.height)
        guard sx.isFinite, sy.isFinite, sx != 0, sy != 0 else { return fill }
        func map(_ p: Point) -> Point { Point(x: to.minX + (p.x - from.minX) * sx, y: to.minY + (p.y - from.minY) * sy) }
        switch fill {
        case .solid: return fill
        case .linear(let stops, let start, let end): return .linear(stops: stops, start: map(start), end: map(end))
        case .radial(let stops, let center, let radius):
            return .radial(stops: stops, center: map(center), radius: radius * abs(sx * sy).squareRoot())
        }
    }

    /// `fill`'s gradient with `stops` in place of its own; a solid is returned as it is.
    private static func with(_ fill: Fill, stops: [GradientStop]) -> Fill {
        switch fill {
        case .solid: fill
        case .linear(_, let start, let end): .linear(stops: stops, start: start, end: end)
        case .radial(_, let center, let radius): .radial(stops: stops, center: center, radius: radius)
        }
    }

    private static func center(of box: Rect) -> Point { Point(x: (box.minX + box.maxX) / 2, y: (box.minY + box.maxY) / 2) }

    /// Sine and cosine of an angle in degrees, exact at multiples of 90 so a square angle writes whole points.
    private static func sinCos(degrees: Double) -> (sin: Double, cos: Double) {
        let turned = degrees.truncatingRemainder(dividingBy: 360)
        switch turned < 0 ? turned + 360 : turned {
        case 0: return (0, 1)
        case 90: return (1, 0)
        case 180: return (0, -1)
        case 270: return (-1, 0)
        default:
            let radians = turned * .pi / 180
            return (sin(radians), cos(radians))
        }
    }
}
