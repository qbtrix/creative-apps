// GlyphRasterizer.swift: shell-text's glyph drawing on Core Text (ST-7),
// moved from Halo's HaloTextRasterizer (its context set-up and CTLine
// drawing; Halo swaps its own copy for this service in W3, packet "Adopted
// later"). The frame is an 8-bit sRGB premultiplied bitmap context exactly
// `width` by `height`, cleared. Each grapheme of each placed span is one CTLine
// in the span's font (CoreTextMeasurer's font: family, weight, italic, the
// system UI font as fallback) and colour (its straight-alpha `rgba`), drawn
// with its baseline origin at the grapheme's origin and turned by its angle.
// Origins are frame space, y down; degrees turn clockwise on screen. The
// context is y up, so a frame point (x, y) is (x, height - y) there and an
// angle turns by its negative; its first row in memory is the top row, which
// is MediaFrame's order. The bytes are then unpremultiplied into the frame.
// A size past 1 GiB or a context Core Graphics won't make throws
// `notAvailable`; nothing here force-unwraps or indexes unchecked.
#if canImport(AppKit)
import AppKit
import CoreGraphics
import CoreText
import SuiteModel

/// Draws placed spans into a straight-alpha sRGB frame.
public struct GlyphRasterizer: GlyphRasterizing {
    /// The largest frame in bytes, as FakeText's.
    static let maxBytes = 1 << 30

    public init() {}

    public func draw(_ spans: [PlacedSpan], width: Int, height: Int) throws(SuiteError) -> MediaFrame {
        let pixels = width.multipliedReportingOverflow(by: height)
        let bytes = pixels.partialValue.multipliedReportingOverflow(by: 4)
        guard width > 0, height > 0, !pixels.overflow, !bytes.overflow, bytes.partialValue <= Self.maxBytes else {
            throw .notAvailable("A \(width) by \(height) frame is too big to draw text into.")
        }
        var placed: [PlacedSpan] = []
        for span in spans { placed.append(try TextRules.validated(span)) }
        guard let space = CGColorSpace(name: CGColorSpace.sRGB) else {
            throw .notAvailable("Core Graphics has no sRGB colour space to draw text in.")
        }
        var rgba = [UInt8](repeating: 0, count: bytes.partialValue)
        let drawn = rgba.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.setShouldAntialias(true)
            context.setAllowsFontSmoothing(false)
            context.setShouldSmoothFonts(false)
            for span in placed { Self.draw(span, in: context, height: height) }
            context.flush()
            return true
        }
        guard drawn else { throw .notAvailable("Core Graphics couldn't make a \(width) by \(height) frame for text.") }
        Self.unpremultiply(&rgba)
        return try MediaFrame(width: width, height: height, rgba: rgba)
    }

    /// Each grapheme of `placed` at its origin and angle, in its span's font and colour.
    static func draw(_ placed: PlacedSpan, in context: CGContext, height: Int) {
        let (font, _) = CoreTextMeasurer.font(placed.span)
        let rgba: [UInt8] = placed.span.rgba.count == 4 ? placed.span.rgba : [0, 0, 0, 255]
        let unit = { (index: Int) -> CGFloat in rgba.indices.contains(index) ? CGFloat(rgba[index]) / 255 : 1 }
        let color = CGColor(srgbRed: unit(0), green: unit(1), blue: unit(2), alpha: unit(3))
        let attributes: [CFString: Any] = [kCTFontAttributeName: font, kCTForegroundColorAttributeName: color]
        for (grapheme, (origin, degrees)) in zip(placed.span.string, zip(placed.origins, placed.degrees)) {
            guard origin.x.isFinite, origin.y.isFinite, degrees.isFinite,
                  let string = CFAttributedStringCreate(nil, String(grapheme) as CFString, attributes as CFDictionary)
            else { continue }
            let line = CTLineCreateWithAttributedString(string)
            context.saveGState()
            context.translateBy(x: CGFloat(origin.x), y: CGFloat(Double(height) - origin.y))
            context.rotate(by: CGFloat(-degrees * .pi / 180))
            context.textMatrix = .identity
            context.textPosition = .zero
            CTLineDraw(line, context)
            context.restoreGState()
        }
    }

    /// Premultiplied RGBA bytes to straight alpha, rounding to nearest; a clear pixel stays 0.
    static func unpremultiply(_ rgba: inout [UInt8]) {
        for alphaIndex in stride(from: 3, to: rgba.count, by: 4) {
            let alpha = Int(rgba[alphaIndex])
            guard alpha > 0, alpha < 255 else { continue }
            for index in (alphaIndex - 3)..<alphaIndex {
                rgba[index] = UInt8(min(255, (Int(rgba[index]) * 255 + alpha / 2) / alpha))
            }
        }
    }
}
#endif
