// Fakes/FakeTextRasterizer.swift: a small, predictable TextRasterizing
// (#430). Simpler than HaloApp's CoreText one: it measures with
// HaloTextContent's estimate (0.6 em a character, one em tall) and draws a
// box of the layer's color, its sides rounded up to whole pixels. Linux-safe; never used by `.live`.
import CoreRaster

public struct FakeTextRasterizer: TextRasterizing {
    public init() {}
    public func measure(_ text: HaloTextContent) -> HaloLayerRect {
        let estimate = HaloTextContent(string: text.string, fontSize: text.fontSize)
        return HaloLayerRect(x: 0, y: 0, width: estimate.width, height: estimate.height)
    }
    public func rasterize(_ text: HaloTextContent, color: HaloLayerColor) throws -> PixelBuffer {
        let box = measure(text)
        return try PixelBuffer(
            width: Self.side(box.width), height: Self.side(box.height),
            fill: RGBA(r: Float(color.red), g: Float(color.green), b: Float(color.blue), a: 1))
    }

    /// A buffer side for a measured length: rounded up (past rounding noise),
    /// at least 1, at most 16,384, and 1 for NaN.
    static func side(_ length: Double) -> Int {
        length.isNaN ? 1 : Int(min(max((length - 1e-9).rounded(.up), 1), 16_384))
    }
}
