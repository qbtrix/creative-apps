// GradientSVG.swift (gradient-fill GF-1 stub, GF-7 body): a fill as an SVG gradient definition. It writes what
// FlareCore's internal `SVGExporter.gradient(_:id:)` writes, because that function isn't public; once core makes it
// public the kernel calls it and drops its body.

public enum GradientSVG {
    /// The `<linearGradient>` or `<radialGradient>` for `fill` with id `id`, its points in user space, each stop's
    /// offset and colour, `stop-opacity` only below 1; "" for a solid. Stub: ""; GF-7 fills this in.
    public static func definition(_ fill: Fill, id: String) -> String { "" }
}
