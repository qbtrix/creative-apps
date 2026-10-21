// StrokeRules.swift (stroke-style SS-1 stubs; SS-5 width, join, cap and presets; SS-7 dash and trim): the width
// limits, the dash presets scaled by width, and the path a stroke paints, once, so the canvas, the SVG and the
// raster outline draw the same dashes. Dash and trim maths are FlareCore's path ops (`Path.trimmed`, `Path.dashed`);
// these rules only choose and order them: trimmed first, then dashed.
import FlareCore

public enum StrokeRules {
    /// The widths a stroke takes, in points, and the most entries a dash pattern holds.
    public static let widths = 0.0...1000.0, maxDashEntries = 64
    /// Why dash and trim can't run on a core without FlareCore's stroke fields; the editor's `dashHelp` before SS-d.
    public static let waitingCore = "Dashes and trim need creative-core's stroke fields."
    /// How finely `paintedPath` flattens curves before it trims and dashes them, in points.
    public static let tolerance = 0.25
    /// What an app's stroke set throws until it runs the stroke commands (Design's `setStroke` before DK-6).
    public static let notBuilt = CatalogError.notBuilt(id: "stroke", feature: "an app's stroke commands")

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
    /// The preset `stroke`'s pattern matches at its width, else `.custom`; `.solid` for no dash.
    public static func preset(of stroke: VectorStroke) -> DashPreset {
        let drawn = dash(of: stroke).pattern
        return [DashPreset.solid, .dashed, .dotted].first { pattern($0, width: stroke.width) == drawn } ?? .custom
    }
    /// `stroke`'s dash pattern and phase, in points; `([], 0)` for a solid stroke.
    public static func dash(of stroke: VectorStroke) -> (pattern: [Double], phase: Double) { (stroke.dash, stroke.dashPhase) }
    /// `stroke`'s trim as fractions and an offset in turns; nil when it has none.
    public static func trim(of stroke: VectorStroke) -> (start: Double, end: Double, offset: Double)? {
        stroke.trim.map { (start: $0.start, end: $0.end, offset: $0.offset) }
    }
    /// Whether `pattern` is one FlareCore dashes: empty (solid), or at most `maxDashEntries` finite lengths >= 0
    /// with a positive, finite sum.
    static func isValidPattern(_ pattern: [Double]) -> Bool {
        let sum = pattern.reduce(0, +)
        return pattern.isEmpty || (pattern.count <= maxDashEntries && pattern.allSatisfy { $0.isFinite && $0 >= 0 }
            && sum > 0 && sum.isFinite)
    }
    /// The path a stroke paints: trimmed, then dashed; `path` itself for a plain stroke. A trim that keeps the whole
    /// path is skipped, and one whose start equals its end paints nothing (an empty path, not an error).
    public static func paintedPath(_ path: Path, _ stroke: VectorStroke) throws -> Path {
        var out = path
        if let trim = stroke.trim, !trim.isWhole {
            guard trim.start != trim.end else { return Path(elements: []) }
            out = try out.trimmed(start: trim.start, end: trim.end, offset: trim.offset, mode: trim.mode, tolerance: tolerance)
        }
        if !stroke.dash.isEmpty { out = try out.dashed(stroke.dash, phase: stroke.dashPhase, tolerance: tolerance) }
        return out
    }
}
