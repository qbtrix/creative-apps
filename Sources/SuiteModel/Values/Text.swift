// Text.swift: the values of the suite's one text service (shell-text ST-1):
// a styled span, what measuring it gives (one advance per grapheme), a span
// placed for drawing, and the Mac's font families and faces. Layout is
// creative-core `text-engine`'s; these mirror its `GlyphRunMetrics` and
// `PlacedGlyph`. The rules are ST-3's Text+Rules.swift. Foundation free,
// Linux-safe, Sendable.

/// A point in a frame or on a canvas, y down unless a caller says otherwise.
public struct SuitePoint: Hashable, Codable, Sendable {
    public var x: Double, y: Double

    public init(x: Double, y: Double) { self.x = x; self.y = y }
}

/// One run of text in one style. An empty family is the system UI font;
/// weight is 100...900 in hundreds; `rgba` is 4 straight-alpha bytes.
public struct TextSpan: Hashable, Codable, Sendable {
    public var string: String
    public var fontFamily: String
    public var fontSize: Double
    public var weight: Int
    public var italic: Bool
    public var rgba: [UInt8]
    /// Extra space after each grapheme, in points.
    public var tracking: Double

    public init(_ string: String, fontFamily: String = "", fontSize: Double = 12, weight: Int = 400,
                italic: Bool = false, rgba: [UInt8] = [0, 0, 0, 255], tracking: Double = 0) {
        self.string = string; self.fontFamily = fontFamily; self.fontSize = fontSize; self.weight = weight
        self.italic = italic; self.rgba = rgba; self.tracking = tracking
    }
}

/// A measured span: one advance per grapheme, the line's ascent and descent,
/// and the family that drew it (the fallback's name when the asked one is missing).
public struct SpanMetrics: Hashable, Codable, Sendable {
    public var advances: [Double]
    public var ascent: Double, descent: Double
    public var resolvedFamily: String

    public init(advances: [Double], ascent: Double, descent: Double, resolvedFamily: String) {
        self.advances = advances; self.ascent = ascent; self.descent = descent; self.resolvedFamily = resolvedFamily
    }
}

/// A span laid out for drawing: each grapheme's baseline origin and angle in degrees.
public struct PlacedSpan: Hashable, Sendable {
    public var span: TextSpan
    public var origins: [SuitePoint]
    public var degrees: [Double]

    public init(span: TextSpan, origins: [SuitePoint], degrees: [Double]) {
        self.span = span; self.origins = origins; self.degrees = degrees
    }
}

/// One face of a family, such as "Bold Italic" at weight 700.
public struct FontFace: Hashable, Codable, Sendable {
    public var name: String
    public var weight: Int
    public var italic: Bool

    public init(name: String, weight: Int, italic: Bool) { self.name = name; self.weight = weight; self.italic = italic }
}

/// A font family and its faces, as the font picker lists it.
public struct FontFamily: Hashable, Codable, Sendable, Identifiable {
    public var id: String { name }
    public var name: String
    public var faces: [FontFace]

    public init(name: String, faces: [FontFace]) { self.name = name; self.faces = faces }
}

/// The limits a span is checked against before it is measured or drawn.
public enum TextRules {
    public static let sizes: ClosedRange<Double> = 1...1_600
    public static let maxGraphemes = 100_000
}
