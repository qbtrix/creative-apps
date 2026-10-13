// AuditPixels.swift: the pixel math of the app audit
// (docs/blueprints/app-audit.md). WCAG 2.x relative luminance and contrast
// ratio, and the "ink" of a frame in a screenshot: how strongly whatever is
// drawn there stands off its background.
//
// It lives in the AppAuditTests target, which builds and tests on Linux;
// project.yml compiles it into every UI journey bundle, where
// UITests/Audit.swift calls it. Plain Swift and Foundation, and every name
// nests under `AppAudit`, so nothing here shadows a type in a journey bundle.
import Foundation

enum AppAudit {}

extension AppAudit {
    /// An sRGB image, 8 bits per channel, RGBA row by row with no padding.
    struct Image: Sendable {
        let width: Int
        let height: Int
        let rgba: [UInt8]
    }

    /// A rectangle in points or pixels, origin top left.
    struct Rect: Equatable, Codable, Sendable {
        var x, y, width, height: Double
        var maxX: Double { x + width }
        var maxY: Double { y + height }
    }

    /// How far what is drawn in a frame stands off the frame's background:
    /// both as WCAG values, `contrast` from 1 (nothing drawn) to 21.
    struct Ink: Equatable, Sendable {
        let background: Double
        let contrast: Double
    }

    /// WCAG 2.x relative luminance of an 8-bit sRGB color: 0 black, 1 white.
    static func luminance(_ r: UInt8, _ g: UInt8, _ b: UInt8) -> Double {
        0.2126 * linear[Int(r)] + 0.7152 * linear[Int(g)] + 0.0722 * linear[Int(b)]
    }

    /// WCAG contrast ratio of two luminances, from 1 (equal) to 21.
    static func contrast(_ a: Double, _ b: Double) -> Double {
        (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// The ink of the pixels inside `rect` (in pixels, cut to the image and
    /// rounded inward so no neighbor bleeds in). The background is the most
    /// common 8-bit luma there; ink pixels are at least `inkStep` from it, and
    /// the ink is the 90th percentile of their contrast, which skips
    /// antialiased edges but keeps the cores of strokes. Nil when fewer than
    /// 16 pixels are inside or the buffer doesn't match its size.
    static func ink(of image: Image, in rect: Rect) -> Ink? {
        let x0 = max(0, Int(rect.x.rounded(.up))), x1 = min(image.width, Int(rect.maxX.rounded(.down)))
        let y0 = max(0, Int(rect.y.rounded(.up))), y1 = min(image.height, Int(rect.maxY.rounded(.down)))
        guard image.rgba.count == image.width * image.height * 4, x1 > x0, y1 > y0,
            (x1 - x0) * (y1 - y0) >= 16
        else { return nil }
        var lumas = [UInt8](), values = [Double](), buckets = [Int](repeating: 0, count: 256)
        for y in y0..<y1 {
            for x in x0..<x1 {
                let i = (y * image.width + x) * 4
                let (r, g, b) = (image.rgba[i], image.rgba[i + 1], image.rgba[i + 2])
                // Rec. 709 weights on the encoded values; the weights sum to 256.
                let weighted: Int = 54 * Int(r) + 183 * Int(g) + 19 * Int(b)
                let luma = UInt8(weighted >> 8)
                lumas.append(luma)
                values.append(luminance(r, g, b))
                buckets[Int(luma)] += 1
            }
        }
        let mode = UInt8(buckets.indices.max { buckets[$0] < buckets[$1] } ?? 0)
        let ground = zip(lumas, values).filter { $0.0 == mode }.map(\.1)
        let background = ground.reduce(0, +) / Double(max(ground.count, 1))
        let ratios = values.map { contrast($0, background) }.filter { $0 >= inkStep }.sorted()
        guard ratios.count >= 3 else { return Ink(background: background, contrast: 1) }
        return Ink(background: background, contrast: ratios[Int(Double(ratios.count - 1) * 0.9)])
    }

    /// The smallest contrast against the background that counts as ink.
    static let inkStep = 1.25

    /// Linear light for each 8-bit sRGB channel value.
    private static let linear: [Double] = (0...255).map { value in
        let c = Double(value) / 255
        return c <= 0.04045 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
    }
}
