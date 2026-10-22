// TextStyleRules.swift (text-style TS-1 declared, TS-5 built): the ranges a text style's numbers keep, the
// one setter that clamps into them, and the one layout every app's canvas, inspector and exporter takes its lines from.
// `layout` is the packet's TextStyleLayout: FlareCore's `TextLayout.lay` over the style, measured by the app's closure.
import FlareCore

/// The three numbers of a text style the inspector scrubs.
public enum TextStyleField: String, CaseIterable, Codable, Sendable { case size, lineHeight, tracking }

public enum TextStyleRules {
    /// What a text command's run throws until TS-6 builds the bodies.
    public static let notBuilt = CatalogError.notBuilt(id: "text", feature: "text-style TS-6")

    /// The range `field` keeps: size 1...1600 pt, line height 0.5...4, tracking -100...500 thousandths of an em.
    public static func range(_ field: TextStyleField) -> ClosedRange<Double> {
        switch field {
        case .size: 1...1600
        case .lineHeight: 0.5...4
        case .tracking: -100...500
        }
    }

    /// `style` with `field` set to `value` clamped into its range; NaN keeps the old value.
    public static func setting(_ style: TextStyle, _ field: TextStyleField, to value: Double) -> TextStyle {
        guard !value.isNaN else { return style }
        let kept = min(max(value, range(field).lowerBound), range(field).upperBound)
        var style = style
        switch field {
        case .size: style.size = kept
        case .lineHeight: style.paragraph.lineHeight = kept
        case .tracking: style.paragraph.tracking = kept
        }
        return style
    }

    /// `string` laid out in `style`: `advances` measures one run's graphemes (each grapheme's advance in points, and
    /// the run's ascent and descent), tracking becomes points at `style.size`. Line height, justify (every wrapped line
    /// but a paragraph's last spans the box) and breaking are FlareCore's. Throws what `TextLayout.lay` throws.
    public static func layout(_ string: String, style: TextStyle,
                              advances: ([String]) -> (advances: [Double], ascent: Double, descent: Double)) throws -> TextLayout {
        var paragraph = style.paragraph
        paragraph.tracking = style.paragraph.tracking / 1000 * style.size
        let shape = TextShape(string: string, fontFamily: style.family, fontSize: style.size, position: Point(x: 0, y: 0),
                              paragraph: paragraph)
        let graphemes = Array(string)
        let measured = try shape.resolvedRuns.map { run in
            let span = graphemes.dropFirst(run.start).prefix(run.length).map(String.init)
            let metrics = advances(span)
            return try GlyphRunMetrics(advances: metrics.advances, ascent: metrics.ascent, descent: metrics.descent)
        }
        return try TextLayout.lay(shape, measured: measured)
    }
}
