// LiveText.swift: shell-text's live TextServices (ST-8), in SuiteText so the
// apps (through SuiteShell) and headless tools share it. Joins the three
// Core Text parts: CoreTextMeasurer measures, FontCatalog lists and
// GlyphRasterizer draws. Each part validates its spans through TextRules, so
// this only forwards. Layout stays in creative-core: callers place graphemes
// from these metrics and hand the placed spans back to draw.
#if canImport(AppKit)
import SuiteModel

/// Measures, lists fonts and draws placed glyphs on Core Text.
public struct LiveText: TextServices {
    let measurer = CoreTextMeasurer()
    let catalog = FontCatalog()
    let rasterizer = GlyphRasterizer()

    public init() {}

    public func measure(_ spans: [TextSpan]) throws(SuiteError) -> [SpanMetrics] {
        try measurer.measure(spans)
    }

    public func families() -> [FontFamily] { catalog.families() }

    public func draw(_ spans: [PlacedSpan], width: Int, height: Int) throws(SuiteError) -> MediaFrame {
        try rasterizer.draw(spans, width: width, height: height)
    }
}
#endif
