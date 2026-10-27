// HaloTextAdapter.swift: Halo's TextRasterizing on the suite's one text service (SuiteModel's TextServices; on a
// Mac that is SuiteText's LiveText), so a host that holds the shared service hands it to Halo instead of keeping a
// second Core Text copy. The afterglow CLI and MCP use it for headless `text.set`.
// A text layer is one line of its string (newlines as spaces) in the system UI font (an empty family) at its size,
// clamped to TextRules' 1 to 1,600 points, in the layer's colour. `measure` is the advances' sum by ascent + descent,
// each rounded up to whole pixels (1 to 16,384); a refused measure is a 1 by 1 box. `rasterize` places grapheme i at
// the sum of the advances before it, on the baseline `descent` above the box's bottom (height - descent from the top,
// HaloTextRasterizer's rule), draws through the service and decodes its straight 8-bit sRGB frame to linear,
// premultiplied light with CoreRaster's PixelBuffer(rgba8:), the buffer TextRasterizing promises. Linux-safe.
import CoreRaster
import SuiteModel

/// Draws and measures Halo text layers through a suite text service.
public struct HaloTextAdapter: TextRasterizing {
    public let text: any TextServices

    public init(_ text: any TextServices) { self.text = text }

    public func measure(_ content: HaloTextContent) -> HaloLayerRect {
        let box = (try? metrics(content)).map(Self.box) ?? (width: 1, height: 1)
        return HaloLayerRect(x: 0, y: 0, width: Double(box.width), height: Double(box.height))
    }

    public func rasterize(_ content: HaloTextContent, color: HaloLayerColor) throws -> PixelBuffer {
        let span = Self.span(content, color: color)
        let m = try metrics(content)
        let box = Self.box(m)
        let baseline = Double(box.height) - m.descent
        var x = 0.0
        let origins = m.advances.map { advance in
            defer { x += advance }
            return SuitePoint(x: x, y: baseline)
        }
        let placed = PlacedSpan(span: span, origins: origins, degrees: origins.map { _ in 0 })
        let frame = try text.draw([placed], width: box.width, height: box.height)
        return try PixelBuffer(rgba8: frame.rgba, width: frame.width, height: frame.height)
    }

    /// The service's metrics for `content`'s line; throws when it measures nothing.
    func metrics(_ content: HaloTextContent) throws -> SpanMetrics {
        guard let m = try text.measure([Self.span(content, color: nil)]).first else {
            throw SuiteError.notAvailable("The text service measured nothing.")
        }
        return m
    }

    /// `content` as one span: newlines as spaces, the system family, its size clamped, `color` as bytes.
    static func span(_ content: HaloTextContent, color: HaloLayerColor?) -> TextSpan {
        let size = content.fontSize.isFinite ? min(max(content.fontSize, TextRules.sizes.lowerBound), TextRules.sizes.upperBound)
            : TextRules.sizes.lowerBound
        let rgba: [UInt8] = color.map { [byte($0.red), byte($0.green), byte($0.blue), 255] } ?? [0, 0, 0, 255]
        return TextSpan(String(content.string.map { $0.isNewline ? " " : $0 }), fontSize: size, rgba: rgba)
    }

    /// The whole-pixel line box of `m`.
    static func box(_ m: SpanMetrics) -> (width: Int, height: Int) {
        (FakeTextRasterizer.side(m.advances.reduce(0, +)), FakeTextRasterizer.side(m.ascent + m.descent))
    }

    /// A 0...1 channel as a byte; NaN is 0.
    static func byte(_ value: Double) -> UInt8 {
        value.isNaN ? 0 : UInt8((min(max(value, 0), 1) * 255).rounded())
    }
}
