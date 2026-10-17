// HaloTextRasterizer.swift: Halo's text rasterizer on Core Text (#430,
// text-layers TX-4), which HaloLaunch sets as `services.text`. A text layer
// is one CTLine of its string in the system UI font at its size (the font
// HaloViewerCanvas measures its ascent with). `measure` is the line's
// typographic box: x 0, y 0, the advance width and ascent + descent, each
// rounded up to whole pixels (1 to 16,384). `rasterize` draws that line into
// a float, premultiplied, linear sRGB bitmap exactly the box's size, its
// baseline `descent` above the bottom (height - descent from the top,
// viewer-playback's pinned baseline rule), in the layer's sRGB color matched
// to linear by Core Graphics, then copies it top row first into a PixelBuffer
// (linear light, premultiplied, (0, 0) the box's top left). A context Core
// Graphics won't make throws; nothing here force-unwraps or crashes.
import CoreGraphics
import CoreRaster
import CoreText
import Foundation
import HaloModel

enum HaloTextRasterizerError: Error, Equatable {
    /// Core Graphics made no linear float bitmap context or attributed string.
    case contextUnavailable
}

struct HaloTextRasterizer: TextRasterizing {
    /// The longest box side in pixels; keeps the bitmap allocation bounded.
    static let maxSide = 16_384.0

    init() {}

    func measure(_ text: HaloTextContent) -> HaloLayerRect {
        let layout = Self.layout(text, color: nil)
        return HaloLayerRect(x: 0, y: 0, width: layout.width, height: layout.height)
    }

    func rasterize(_ text: HaloTextContent, color: HaloLayerColor) throws -> PixelBuffer {
        guard let space = CGColorSpace(name: CGColorSpace.linearSRGB) else {
            throw HaloTextRasterizerError.contextUnavailable
        }
        let srgb = CGColor(
            srgbRed: Self.unit(color.red), green: Self.unit(color.green), blue: Self.unit(color.blue), alpha: 1)
        let linear = srgb.converted(to: space, intent: .defaultIntent, options: nil) ?? srgb
        let layout = Self.layout(text, color: linear)
        guard let line = layout.line else { throw HaloTextRasterizerError.contextUnavailable }
        let width = Int(layout.width), height = Int(layout.height)
        var out = try PixelBuffer(width: width, height: height)
        var floats = [Float](repeating: 0, count: width * height * 4)
        let drawn = floats.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(
                data: raw.baseAddress, width: width, height: height, bitsPerComponent: 32,
                bytesPerRow: width * 4 * MemoryLayout<Float>.size, space: space, bitmapInfo: Self.bitmapInfo)
            else { return false }
            context.setShouldAntialias(true)
            context.setAllowsFontSmoothing(false)
            context.setShouldSmoothFonts(false)
            context.textMatrix = .identity
            // Core Graphics bitmaps are y-up: the baseline sits `descent` above the bottom row.
            context.textPosition = CGPoint(x: 0, y: layout.descent)
            CTLineDraw(line, context)
            context.flush()
            return true
        }
        guard drawn else { throw HaloTextRasterizerError.contextUnavailable }
        // The bitmap's first row in memory is the top row, as PixelBuffer's.
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                guard i + 3 < floats.count else { continue }
                try out.setPixel(x: x, y: y, RGBA(r: floats[i], g: floats[i + 1], b: floats[i + 2], a: floats[i + 3]))
            }
        }
        return out
    }

    /// 128-bit RGBA: 32-bit float components in host order, alpha last, premultiplied.
    static let bitmapInfo = CGBitmapInfo(alpha: .premultipliedLast, component: .float, byteOrder: .order32Host)

    /// One laid-out line: the CTLine (nil when Core Foundation made no
    /// attributed string), the whole-pixel box and the line's descent.
    struct Layout {
        var line: CTLine?
        var width: Double
        var height: Double
        var descent: CGFloat
    }

    /// `text` as one CTLine in the system UI font, with `color` as its
    /// foreground when given, and its typographic box rounded up.
    static func layout(_ text: HaloTextContent, color: CGColor?) -> Layout {
        guard let line = line(text, color: color) else { return Layout(line: nil, width: 1, height: 1, descent: 0) }
        var ascent: CGFloat = 0, descent: CGFloat = 0, leading: CGFloat = 0
        let advance = CTLineGetTypographicBounds(line, &ascent, &descent, &leading)
        return Layout(
            line: line, width: side(advance), height: side(Double(ascent + descent)), descent: descent)
    }

    /// The CTLine of `text`'s string (newlines as spaces: one line) in the
    /// system UI font at its size; nil when no attributed string is made.
    static func line(_ text: HaloTextContent, color: CGColor?) -> CTLine? {
        guard let font = CTFontCreateUIFontForLanguage(.system, fontSize(text.fontSize), nil) else { return nil }
        var attributes: [CFString: Any] = [kCTFontAttributeName: font]
        if let color { attributes[kCTForegroundColorAttributeName] = color }
        let string = text.string.replacingNewlines()
        guard let attributed = CFAttributedStringCreate(nil, string as CFString, attributes as CFDictionary) else {
            return nil
        }
        return CTLineCreateWithAttributedString(attributed)
    }

    /// A font size Core Text draws: `size` when finite and positive (at
    /// most `maxSide`), else 1 (0 would ask Core Text for its default size).
    static func fontSize(_ size: Double) -> CGFloat {
        size.isFinite && size > 0 ? CGFloat(min(size, maxSide)) : 1
    }

    /// A box side: `length` rounded up past rounding noise, 1 to `maxSide`, 1 for NaN.
    static func side(_ length: Double) -> Double {
        length.isNaN ? 1 : min(max((length - 1e-9).rounded(.up), 1), maxSide)
    }

    /// A color component clamped to 0...1, 0 for NaN.
    static func unit(_ value: Double) -> CGFloat {
        value.isNaN ? 0 : CGFloat(min(max(value, 0), 1))
    }
}

extension String {
    /// The string with each newline character as a space.
    fileprivate func replacingNewlines() -> String {
        String(map { $0.isNewline ? " " : $0 })
    }
}
