// StrokeRules.swift (stroke-style SS-1 stubs; SS-5 width, join, cap and presets; SS-7 dash and trim): the width
// limits, the dash presets scaled by width, and the path a stroke paints, once, so the canvas, the SVG and the
// raster outline draw the same dashes. Dash and trim maths are FlareCore's path ops; these rules only choose and
// order them. Dash, trim and the painted path return the neutral value they name until SS-7 fills them in.
import FlareCore

public enum StrokeRules {
    /// The widths a stroke takes, in points, and the most entries a dash pattern holds.
    public static let widths = 0.0...1000.0, maxDashEntries = 64
    /// Why dash and trim can't run until the core bump brings FlareCore's stroke fields.
    public static let waitingCore = "Dashes and trim need creative-core's stroke fields."
    /// What a stroke command's run throws until SS-6 builds the bodies.
    public static let notBuilt = CatalogError.notBuilt(id: "stroke", feature: "stroke-style SS-6")

    /// `width` clamped to `widths`; NaN reads as the narrowest.
    public static func clampedWidth(_ width: Double) -> Double {
        width.isNaN ? widths.lowerBound : min(max(width, widths.lowerBound), widths.upperBound)
    }
    /// `preset`'s pattern for a stroke `width` wide: dashed `[4w, 2w]`, dotted `[0, 2w]`, solid and custom `[]`, with
    /// `w = max(width, 1)`, so a hairline's dashes stay visible.
    public static func pattern(_ preset: DashPreset, width: Double) -> [Double] {
        let w = max(clampedWidth(width), 1)
        switch preset {
        case .dashed: return [4 * w, 2 * w]
        case .dotted: return [0, 2 * w]
        case .solid, .custom: return []
        }
    }
    /// The preset `stroke`'s pattern matches at its width, else `.custom`; `.solid` while `dash(of:)` is neutral.
    public static func preset(of stroke: VectorStroke) -> DashPreset {
        let drawn = dash(of: stroke).pattern
        return [DashPreset.solid, .dashed, .dotted].first { pattern($0, width: stroke.width) == drawn } ?? .custom
    }
    /// `stroke`'s dash pattern and phase. Stub: `([], 0)` until SS-7.
    public static func dash(of stroke: VectorStroke) -> (pattern: [Double], phase: Double) { ([], 0) }
    /// `stroke`'s trim as fractions and an offset in turns; nil when it has none. Stub: nil until SS-7.
    public static func trim(of stroke: VectorStroke) -> (start: Double, end: Double, offset: Double)? { nil }
    /// The path a stroke paints: trimmed, then dashed; `path` itself for a plain stroke.
    /// Stub: returns `path`; SS-7 fills this in on the bumped core.
    public static func paintedPath(_ path: Path, _ stroke: VectorStroke) throws -> Path { path }
}
