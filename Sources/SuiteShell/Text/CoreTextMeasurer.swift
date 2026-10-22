// CoreTextMeasurer.swift: shell-text's measurer on Core Text (ST-4). Each
// span is one CTLine in its font: the family through a font descriptor with
// the weight trait, the system UI font (NSFont's, at the weight) for an empty
// or unknown family, which `resolvedFamily` then names as FakeText's
// "System UI"; italic through the symbolic traits. Each glyph run's glyphs are
// mapped back to graphemes through the UTF-16 string indices Core Text
// reports: a glyph covers its string index up to the next glyph's, its advance
// splits evenly over the graphemes it covers (an "ffi" ligature gives a third
// to each of f, f and i), and every glyph of one grapheme adds into it (a
// multi-glyph emoji is one advance). Deleted (0xFFFF) and zero-width glyphs
// start no range. Tracking is added once per grapheme here, not as the kern
// attribute, which Core Text applies per character and whose 0 turns kerning
// off. Ascent and descent are the line's typographic bounds (the font's for an
// empty span). Nothing here force-unwraps or indexes unchecked.
#if canImport(AppKit)
import AppKit
import CoreText
import SuiteModel

/// Measures spans through Core Text: one advance per grapheme.
public struct CoreTextMeasurer: TextMeasuring {
    public init() {}

    public func measure(_ spans: [TextSpan]) throws(SuiteError) -> [SpanMetrics] {
        var out: [SpanMetrics] = []
        out.reserveCapacity(spans.count)
        for span in spans { out.append(try Self.measure(TextRules.validated(span))) }
        return out
    }

    static func measure(_ span: TextSpan) throws(SuiteError) -> SpanMetrics {
        let (font, family) = Self.font(span)
        var advances = [Double](repeating: 0, count: span.string.count)
        guard !span.string.isEmpty else {
            return SpanMetrics(advances: [], ascent: Double(CTFontGetAscent(font)),
                               descent: Double(CTFontGetDescent(font)), resolvedFamily: family)
        }
        let attributes = [kCTFontAttributeName: font] as CFDictionary
        guard let string = CFAttributedStringCreate(nil, span.string as CFString, attributes) else {
            throw .notAvailable("Core Text couldn't measure this text.")
        }
        let line = CTLineCreateWithAttributedString(string)
        var ascent: CGFloat = 0, descent: CGFloat = 0
        _ = CTLineGetTypographicBounds(line, &ascent, &descent, nil)
        let clusters = Self.clusters(span.string)
        for run in CTLineGetGlyphRuns(line) as? [CTRun] ?? [] {
            Self.add(run, clusters: clusters, into: &advances)
        }
        let tracking = span.tracking.isFinite ? span.tracking : 0
        return SpanMetrics(advances: advances.map { $0 + tracking }, ascent: Double(ascent),
                           descent: Double(descent), resolvedFamily: family)
    }

    /// The grapheme index of each UTF-16 offset of `string`.
    static func clusters(_ string: String) -> [Int] {
        var map: [Int] = []
        map.reserveCapacity(string.utf16.count)
        for (index, character) in string.enumerated() {
            map.append(contentsOf: repeatElement(index, count: character.utf16.count))
        }
        return map
    }

    /// Adds each of `run`'s glyph advances to the graphemes it covers.
    static func add(_ run: CTRun, clusters: [Int], into advances: inout [Double]) {
        let count = CTRunGetGlyphCount(run)
        guard count > 0 else { return }
        var glyphs = [CGGlyph](repeating: 0, count: count)
        var indices = [CFIndex](repeating: 0, count: count)
        var sizes = [CGSize](repeating: .zero, count: count)
        let all = CFRange(location: 0, length: 0)
        CTRunGetGlyphs(run, all, &glyphs)
        CTRunGetStringIndices(run, all, &indices)
        CTRunGetAdvances(run, all, &sizes)
        let range = CTRunGetStringRange(run)
        let runEnd = range.location + range.length
        let drawn = zip(glyphs, zip(indices, sizes)).filter { $0.0 != 0xFFFF && $0.1.1.width != 0 }
        let starts = Set(drawn.map { $0.1.0 }).sorted()
        let ends = Dictionary(zip(starts, starts.dropFirst() + [runEnd]), uniquingKeysWith: { a, _ in a })
        for (_, (start, size)) in drawn {
            let next = ends[start] ?? runEnd
            guard let first = clusters[safe: start], let last = clusters[safe: max(start, next - 1)] else { continue }
            let low = min(first, last), high = max(first, last)
            let share = Double(size.width) / Double(high - low + 1)
            for grapheme in low...high where advances.indices.contains(grapheme) { advances[grapheme] += share }
        }
    }

    /// `span`'s Core Text font and the family name it resolved to.
    static func font(_ span: TextSpan) -> (CTFont, String) {
        let size = span.fontSize.isFinite && span.fontSize > 0 ? CGFloat(min(span.fontSize, 1_600)) : 12
        let weight = Self.weight(span.weight)
        var font: CTFont = NSFont.systemFont(ofSize: size, weight: weight) as CTFont
        var family = FakeText.systemFamily
        if !span.fontFamily.isEmpty {
            let traits = [kCTFontWeightTrait: weight.rawValue] as CFDictionary
            let attributes: [CFString: Any] = [kCTFontFamilyNameAttribute: span.fontFamily,
                                               kCTFontTraitsAttribute: traits]
            let descriptor = CTFontDescriptorCreateWithAttributes(attributes as CFDictionary)
            let named = CTFontCreateWithFontDescriptor(descriptor, size, nil)
            let resolved = CTFontCopyFamilyName(named) as String
            if resolved.caseInsensitiveCompare(span.fontFamily) == .orderedSame { font = named; family = resolved }
        }
        if span.italic, let slanted = CTFontCreateCopyWithSymbolicTraits(font, 0, nil, .traitItalic, .traitItalic) {
            font = slanted
        }
        return (font, family)
    }

    /// 100...900 (nearest hundred, clamped) as the system's Ultra Light to Black weight.
    static func weight(_ weight: Int) -> NSFont.Weight {
        switch min(max(Int((Double(weight) / 100).rounded()), 1), 9) {
        case 1: .ultraLight
        case 2: .thin
        case 3: .light
        case 5: .medium
        case 6: .semibold
        case 7: .bold
        case 8: .heavy
        case 9: .black
        default: .regular
        }
    }
}

extension Array {
    /// The element at `index`, or nil when it is out of range.
    fileprivate subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
#endif
