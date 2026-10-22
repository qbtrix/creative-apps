// TextMeasuring.swift: shell-text's contract (ST-1). Spans in, per-grapheme
// advances out; the font list; placed glyphs drawn into a frame. Layout sits
// between measuring and drawing, in creative-core `text-engine`. Live:
// SuiteShell's Text/ (ST-4, ST-5, ST-7), which takes over Halo's text
// rasterizer. Linux-safe, Sendable.

/// Measures styled spans.
public protocol TextMeasuring: Sendable {
    /// One metrics per span, each with one advance per grapheme.
    func measure(_ spans: [TextSpan]) throws(SuiteError) -> [SpanMetrics]
}

/// Lists the font families this Mac has.
public protocol FontListing: Sendable {
    /// Every family with its faces, sorted by name.
    func families() -> [FontFamily]
}

/// Draws placed glyphs.
public protocol GlyphRasterizing: Sendable {
    /// `spans` drawn into a clear `width` by `height` frame at their origins and angles.
    func draw(_ spans: [PlacedSpan], width: Int, height: Int) throws(SuiteError) -> MediaFrame
}

/// The whole text service: `SuiteServices.text`.
public typealias TextServices = TextMeasuring & FontListing & GlyphRasterizing
