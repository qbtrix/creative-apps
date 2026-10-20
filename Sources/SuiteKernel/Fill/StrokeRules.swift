// StrokeRules.swift (stroke-style SS-1 stubs; SS-5 width, join, cap and presets; SS-7 dash and trim): the width
// limits, the dash presets scaled by width, and the path a stroke paints, once, so the canvas, the SVG and the
// raster outline draw the same dashes. Dash and trim maths are FlareCore's path ops; these rules only choose and
// order them. Every stub returns its input or the neutral value it names until its task fills it in.
import FlareCore

public enum StrokeRules {
    /// The widths a stroke takes, in points, and the most entries a dash pattern holds.
    public static let widths = 0.0...1000.0, maxDashEntries = 64
    /// Why dash and trim can't run until the core bump brings FlareCore's stroke fields.
    public static let waitingCore = "Dashes and trim need creative-core's stroke fields."
    /// What a stroke command's run throws until SS-6 builds the bodies.
    public static let notBuilt = CatalogError.notBuilt(id: "stroke", feature: "stroke-style SS-6")

    /// `width` clamped to `widths`. Stub: returns `width`; SS-5 fills this in.
    public static func clampedWidth(_ width: Double) -> Double { width }
    /// `preset`'s pattern for a stroke `width` wide: dashed `[4w, 2w]`, dotted `[0, 2w]`, solid and custom `[]`, with
    /// `w = max(width, 1)`. Stub: `[]`; SS-5 fills this in.
    public static func pattern(_ preset: DashPreset, width: Double) -> [Double] { [] }
    /// The preset `stroke`'s pattern matches, else `.custom`. Stub: `.solid` (no stroke has a dash until SS-7).
    public static func preset(of stroke: VectorStroke) -> DashPreset { .solid }
    /// `stroke`'s dash pattern and phase. Stub: `([], 0)` until SS-7.
    public static func dash(of stroke: VectorStroke) -> (pattern: [Double], phase: Double) { ([], 0) }
    /// `stroke`'s trim as fractions and an offset in turns; nil when it has none. Stub: nil until SS-7.
    public static func trim(of stroke: VectorStroke) -> (start: Double, end: Double, offset: Double)? { nil }
    /// The path a stroke paints: trimmed, then dashed; `path` itself for a plain stroke.
    /// Stub: returns `path`; SS-7 fills this in on the bumped core.
    public static func paintedPath(_ path: Path, _ stroke: VectorStroke) throws -> Path { path }
}
