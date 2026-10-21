// TextStyle.swift (text-style TS-1): one text layer's character and paragraph style, laid out by FlareCore's text
// engine so every app's text measures, breaks and aligns the same way. The paragraph is FlareCore's `ParagraphStyle`
// under a kernel name, with one difference the kernel owns: `paragraph.tracking` here is thousandths of an em, and
// `TextStyleRules.layout` converts it to points at the style's size.
import FlareCore

/// A paragraph's layout: FlareCore's `ParagraphStyle` (alignment, line height as a multiple of ascent + descent,
/// tracking, paragraph spacing, an optional box width that wraps and justifies).
public typealias ParagraphStyle = FlareCore.ParagraphStyle

/// Laid-out text: FlareCore's `TextLayout` (lines of graphemes with a baseline, each grapheme's x and the line's width).
public typealias TextLayout = FlareCore.TextLayout

/// A text layer's style: its face, size, colour and paragraph.
public struct TextStyle: Codable, Hashable, Sendable {
    /// The font family's name ("System"), its weight (100 thin to 900 black) and whether the face is italic.
    public var family: String, weight: Int, italic: Bool
    /// The size in points.
    public var size: Double
    /// The colour as 8-bit sRGB red, green, blue and alpha.
    public var rgba: [UInt8]
    /// The paragraph; its `tracking` is in thousandths of an em.
    public var paragraph: ParagraphStyle

    public init(family: String, weight: Int, italic: Bool, size: Double, rgba: [UInt8], paragraph: ParagraphStyle) {
        (self.family, self.weight, self.italic, self.size, self.rgba, self.paragraph) = (family, weight, italic, size, rgba, paragraph)
    }

    /// A new text layer's style: System, 400, upright, 24 pt, black, leading, line height 1.2, no tracking.
    public static let standard = TextStyle(family: "System", weight: 400, italic: false, size: 24, rgba: [0, 0, 0, 255],
                                           paragraph: ParagraphStyle(alignment: .leading, lineHeight: 1.2, tracking: 0))
}

extension TextStyle {
    /// A paragraph's alignment: FlareCore's `TextAlignment` (leading, center, trailing, justified), nested because
    /// SwiftUI owns the top-level name.
    public typealias Alignment = FlareCore.TextAlignment
}
