// HaloTextRasterizer+Style.swift (text-style TS-10, slice TS-halo): a Halo
// text layer off the standard face, or of two lines, set by the kernel's
// layout. The font is the layer's family at its weight and italic ("System"
// is the system UI font with those traits; a family Core Text can't match
// falls back to it), each grapheme's advance in that font feeds
// `HaloTextContent.laidOut`, and each line becomes a CTLine tracked by
// kCTKernAttributeName at its lead x and baseline, flipped into the y-up
// bitmap. The box is the layout's extent rounded up by `side`.
import CoreGraphics
import CoreText
import Foundation
import HaloModel
import SuiteKernel

extension HaloTextRasterizer {
    /// Core Text's normalized weight (-1 to 1, 0 regular) for each hundred of
    /// the layer's 100 to 900 weight.
    static let weights: [CGFloat] = [-0.8, -0.6, -0.4, 0, 0.23, 0.3, 0.4, 0.56, 0.62]

    /// `text` set by the kernel's layout; no lines when the layout refuses.
    static func styled(_ text: HaloTextContent, color: CGColor?) -> Layout {
        let font = font(text)
        let ascent = Double(CTFontGetAscent(font)), descent = Double(CTFontGetDescent(font))
        let setting = text.laidOut { graphemes in
            (graphemes.map { advance($0, font: font) }, ascent, descent)
        }
        guard let setting else { return Layout(line: nil, width: 1, height: 1, descent: 0) }
        let width = side(setting.width), height = side(setting.height)
        var attributes: [CFString: Any] = [
            kCTFontAttributeName: font, kCTKernAttributeName: NSNumber(value: text.trackingPoints)]
        if let color { attributes[kCTForegroundColorAttributeName] = color }
        let placed = setting.lines.compactMap { row -> Placed? in
            guard let attributed = CFAttributedStringCreate(nil, row.text as CFString, attributes as CFDictionary)
            else { return nil }
            return Placed(
                line: CTLineCreateWithAttributedString(attributed),
                origin: CGPoint(x: row.x, y: height - row.baseline))
        }
        return Layout(
            line: placed.first?.line, width: width, height: height, descent: CGFloat(descent), placed: placed)
    }

    /// The layer's family at its weight and italic, at its size.
    static func font(_ text: HaloTextContent) -> CTFont {
        let size = fontSize(text.fontSize)
        let index = min(max((text.style.weight + 50) / 100 - 1, 0), weights.count - 1)
        let italic: CTFontSymbolicTraits = text.style.italic ? .traitItalic : []
        let traits: [CFString: Any] = [
            kCTFontWeightTrait: NSNumber(value: Double(weights[index])),
            kCTFontSymbolicTrait: NSNumber(value: italic.rawValue)]
        let styled = [kCTFontTraitsAttribute: traits] as CFDictionary
        let ui = CTFontCreateUIFontForLanguage(.system, size, nil) ?? CTFontCreateWithName("Helvetica" as CFString, size, nil)
        let system = CTFontCreateWithFontDescriptor(
            CTFontDescriptorCreateCopyWithAttributes(CTFontCopyFontDescriptor(ui), styled), size, nil)
        var font = system
        if text.style.family != TextStyle.standard.family {
            let named = CTFontCreateWithFontDescriptor(CTFontDescriptorCreateWithAttributes(
                [kCTFontFamilyNameAttribute: text.style.family, kCTFontTraitsAttribute: traits] as CFDictionary), size, nil)
            // Core Text substitutes a default face for a family it lacks; the system face is the fallback.
            if (CTFontCopyFamilyName(named) as String) == text.style.family { font = named }
        }
        guard text.style.italic, !CTFontGetSymbolicTraits(font).contains(.traitItalic) else { return font }
        return CTFontCreateCopyWithSymbolicTraits(font, 0, nil, .traitItalic, .traitItalic) ?? font
    }

    /// `grapheme`'s advance in `font`, untracked; 0 when no line is made.
    static func advance(_ grapheme: String, font: CTFont) -> Double {
        let attributes = [kCTFontAttributeName: font] as CFDictionary
        guard let attributed = CFAttributedStringCreate(nil, grapheme as CFString, attributes) else { return 0 }
        let width = CTLineGetTypographicBounds(CTLineCreateWithAttributedString(attributed), nil, nil, nil)
        return width.isFinite ? width : 0
    }
}
