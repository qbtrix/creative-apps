// GradientSVG.swift (gradient-fill GF-7): a fill as an SVG 1.1 gradient definition, in user space. It writes what
// FlareCore's internal `SVGExporter.gradient(_:id:)` writes (the one known copy, because that function isn't public;
// once core makes it public the kernel calls it and drops this body). Numbers go through `StrokeSVG.number` and
// colours through `SampleRules.hex`, the kernel's SVG number and colour writers.

public enum GradientSVG {
    /// The `<linearGradient>` or `<radialGradient>` for `fill` with id `id`, its points in user space, each stop's
    /// offset and colour, `stop-opacity` only below 1; "" for a solid. A radius that would round to 0 is written
    /// unrounded, since r="0" turns the gradient off.
    public static func definition(_ fill: Fill, id: String) -> String {
        let number = StrokeSVG.number
        let open: String, close: String
        switch fill {
        case .solid:
            return ""
        case .linear(_, let start, let end):
            open = #"<linearGradient id="\#(id)" gradientUnits="userSpaceOnUse" "#
                + #"x1="\#(number(start.x))" y1="\#(number(start.y))" x2="\#(number(end.x))" y2="\#(number(end.y))">"#
            close = "</linearGradient>"
        case .radial(_, let center, let radius):
            let rounded = number(radius)
            let r = rounded == "0" && radius > 0 && radius.isFinite ? "\(radius)" : rounded
            open = #"<radialGradient id="\#(id)" gradientUnits="userSpaceOnUse" cx="\#(number(center.x))" cy="\#(number(center.y))" r="\#(r)">"#
            close = "</radialGradient>"
        }
        let stops = fill.stops.map { stop in
            let alpha = stop.color.a.isNaN ? 0 : min(max(stop.color.a, 0), 1)
            let opacity = alpha < 1 ? #" stop-opacity="\#(number(alpha))""# : ""
            return #"<stop offset="\#(number(stop.offset))" stop-color="\#(SampleRules.hex(stop.color).lowercased())"\#(opacity)/>"#
        }
        return ([open] + stops + [close]).joined()
    }
}
