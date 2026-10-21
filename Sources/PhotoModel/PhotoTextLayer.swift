// PhotoTextLayer.swift (text-layers TX-1): what a text layer keeps besides its pixels: the words, the
// kernel's `TextStyle`, where its box's top-left sits on the canvas and the box's width when the words
// wrap. `PhotoLayerKind.text` holds one; the pixels stay in PhotoWorkspace.pixels like any layer's, so the
// layer blends, masks and moves as a pixel layer does. Codable, for the `.ora` attribute TX-6 writes.
// Linux-safe.
import CoreRaster
import SuiteKernel

public struct PhotoTextLayer: Hashable, Sendable, Codable {
    public var words: String
    public var style: TextStyle
    /// The box's top-left, in canvas pixels.
    public var origin: Mask.Point
    /// The box's width in pixels; nil: one line per paragraph, no wrap.
    public var boxWidth: Double?

    public init(words: String, style: TextStyle, origin: Mask.Point, boxWidth: Double?) {
        (self.words, self.style, self.origin, self.boxWidth) = (words, style, origin, boxWidth)
    }

    private enum CodingKeys: String, CodingKey { case words, style, x, y, boxWidth }

    public init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        words = try c.decode(String.self, forKey: .words)
        style = try c.decode(TextStyle.self, forKey: .style)
        origin = Mask.Point(x: try c.decode(Double.self, forKey: .x), y: try c.decode(Double.self, forKey: .y))
        boxWidth = try c.decodeIfPresent(Double.self, forKey: .boxWidth)
    }

    public func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(words, forKey: .words)
        try c.encode(style, forKey: .style)
        try c.encode(origin.x, forKey: .x)
        try c.encode(origin.y, forKey: .y)
        try c.encodeIfPresent(boxWidth, forKey: .boxWidth)
    }
}
