// Fakes/FakeFrameRendering.swift: a small, predictable FrameRendering (#451,
// #430). Simpler than the live type: it fills each item's axis-aligned world
// box with its color, bottom first, with no blend modes and no anti-aliasing.
// Nulls never draw or count; text layers are skipped and counted when `text`
// is nil. Linux-safe; never used by `.live`.
import CoreRaster

public struct FakeFrameRendering: FrameRendering {
    public init() {}
    public func render(_ list: HaloDrawList, width: Int, height: Int, text: (any TextRasterizing)?) throws -> HaloRenderedFrame {
        var pixels = try PixelBuffer(width: max(1, width), height: max(1, height))
        let sx = Double(pixels.width) / Double(max(1, list.width)), sy = Double(pixels.height) / Double(max(1, list.height))
        var skipped = 0
        for item in list.items where item.kind != .null {
            if item.kind == .text, text == nil { skipped += 1; continue }
            let b = item.bounds
            let corners = [(b.x, b.y), (b.x + b.width, b.y), (b.x, b.y + b.height), (b.x + b.width, b.y + b.height)]
                .map { item.matrix.apply(HaloPoint(x: $0.0, y: $0.1)) }
            guard let minX = corners.map(\.x).min(), let maxX = corners.map(\.x).max(),
                let minY = corners.map(\.y).min(), let maxY = corners.map(\.y).max(),
                [minX, maxX, minY, maxY].allSatisfy(\.isFinite)
            else { continue }
            let a = Float(item.opacity)
            let color = RGBA(r: Float(item.color.red) * a, g: Float(item.color.green) * a, b: Float(item.color.blue) * a, a: a)
            let x0 = Self.pixel(minX * sx, in: pixels.width), x1 = Self.pixel(maxX * sx, in: pixels.width)
            let y0 = Self.pixel(minY * sy, in: pixels.height), y1 = Self.pixel(maxY * sy, in: pixels.height)
            guard x0 < x1, y0 < y1 else { continue }
            for y in y0..<y1 { for x in x0..<x1 { try pixels.setPixel(x: x, y: y, color) } }
        }
        return HaloRenderedFrame(pixels: pixels, frame: list.frame, skippedLayerCount: skipped)
    }

    /// `value` truncated to a pixel edge in `0...size`.
    static func pixel(_ value: Double, in size: Int) -> Int {
        Int(min(max(value, 0), Double(size)))
    }
}
