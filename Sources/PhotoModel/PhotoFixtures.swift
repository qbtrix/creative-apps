// PhotoFixtures.swift: the documents of blueprint 4.4, built in code on the
// `.fake` services, never read from disk, for `-PhotoFixture` (S-12), the
// journeys and the model tests. `empty` has no image; `sample` is the UI
// tests' test photo (800 x 600, a sky gradient from blue at the top to orange
// at the bottom, a yellow sun disc centered at (560, 220), radius 90);
// `layered` is `sample` under a "Curves 1" adjustment layer and a masked
// "Paint" layer (a red stroke, Multiply, 60%); `large` is 4000 x 3000 in
// three layers of gradients and noise, built from shared one-color tiles so it
// costs a few buffers, not 12 M pixels each. The blueprint's test-only
// `limit` (about 4 GB) is left out. Each fixture opens with a clean history.
// Linux-safe.
import CoreRaster

/// A built-in document (blueprint 4.4).
public enum PhotoFixture: String, CaseIterable, Sendable {
    case empty, sample, layered, large
}

extension PhotoWorkspace {
    /// The fixture on `.fake` services (blueprint 4.4; `limit` is left out, see S-5).
    public static func fixture(_ name: PhotoFixture) throws -> PhotoWorkspace {
        var workspace = PhotoWorkspace(services: .fake)
        switch name {
        case .empty: break
        case .sample: try workspace.openSample()
        case .layered:
            try workspace.openSample()
            try workspace.addFixtureLayers()
        case .large: try workspace.openLarge()
        }
        return workspace
    }

    /// The sample picture as the one Background layer.
    private mutating func openSample() throws {
        let width = 800, height = 600
        let blue: [Float] = [0.16, 0.42, 0.86], orange: [Float] = [0.98, 0.62, 0.42]
        let sun = try Self.linear([1, 0.86, 0.3])
        var picture = try PixelBuffer(width: width, height: height)
        for y in 0..<height {
            let t = Float(y) / Float(height - 1)
            let sky = try Self.linear(zip(blue, orange).map { $0 + ($1 - $0) * t })
            for x in 0..<width {
                let dx = Double(x) + 0.5 - 560, dy = Double(y) + 0.5 - 220
                try picture.setPixel(x: x, y: y, dx * dx + dy * dy <= 90 * 90 ? sun : sky)
            }
        }
        start(with: TiledPixels(picture), name: "sample.png")
    }

    /// "Curves 1" (a gentle S curve) and above it "Paint": a red stroke,
    /// Multiply at 60%, with a mask that hides it right of x = 512. Paint is
    /// selected.
    private mutating func addFixtureLayers() throws {
        var curves = AdjustmentSettings()
        curves.apply(.curvePoints([CurvePoint(x: 0, y: 0), CurvePoint(x: 0.25, y: 0.18),
                                   CurvePoint(x: 0.75, y: 0.82), CurvePoint(x: 1, y: 1)]))
        _ = insertLayer(named: "Curves 1", pixels: nil, kind: .adjustment(curves), at: 0)

        let red = try Self.linear([0.86, 0.1, 0.1])
        var stroke = try PixelBuffer(width: 800, height: 600)
        // A 24 px line from (120, 460) to (680, 360): y = 460 - (x - 120) * 100 / 560.
        for x in 120..<680 {
            let center = 460 - Double(x - 120) * 100 / 560
            for y in Int(center - 12)..<Int(center + 12) { try stroke.setPixel(x: x, y: y, red) }
        }
        let paint = insertLayer(named: "Paint", pixels: TiledPixels(stroke), kind: .pixels, at: 0)
        if let at = index(of: paint) {
            layers[at].blendMode = .multiply
            layers[at].opacity = 0.6
            layers[at].hasMask = true
        }
        let white = RGBA(r: 1, g: 1, b: 1, a: 1), black = RGBA(r: 0, g: 0, b: 0, a: 1)
        masks[paint] = try Self.tiled(width: 800, height: 600) { column, _ in column < 2 ? white : black }
        selectedLayerID = paint
        touch(.all)
    }

    /// Three 4000 x 3000 layers, top first: "Noise" (scattered translucent
    /// tiles), "Gradient" (a translucent left-to-right ramp) and "Background"
    /// (a top-to-bottom ramp).
    private mutating func openLarge() throws {
        let width = 4000, height = 3000
        let background = try Self.tiled(width: width, height: height) { _, row in
            RGBA(r: 0.05 + Float(row) * 0.06, g: 0.2, b: 0.8 - Float(row) * 0.05, a: 1)
        }
        start(with: background, name: "large.png")
        let ramp = try Self.tiled(width: width, height: height) { column, _ in
            RGBA(r: 0, g: Float(column) / 16, b: 0, a: 0.5).premultiplied()
        }
        _ = insertLayer(named: "Gradient", pixels: ramp, kind: .pixels, at: 0)
        let palette = [RGBA(r: 1, g: 1, b: 1, a: 0.3), RGBA(r: 0, g: 0, b: 0, a: 0.3), .clear,
                       RGBA(r: 0.9, g: 0.4, b: 0.1, a: 0.4)].map { $0.premultiplied() }
        let noise = try Self.tiled(width: width, height: height) { column, row in
            palette[(column * 3 + row * 5 + column * row) % palette.count]
        }
        selectedLayerID = insertLayer(named: "Noise", pixels: noise, kind: .pixels, at: 0)
        touch(.all)
    }

    /// `width` x `height` pixels where each tile is one color, by its column
    /// and row; tiles of one size and color share one buffer.
    private static func tiled(width: Int, height: Int, color: (Int, Int) -> RGBA) throws -> TiledPixels {
        var layer = try TiledPixels(width: width, height: height)
        var made: [PixelRect: [RGBA: PixelBuffer]] = [:]
        for i in layer.tiles.indices {
            let rect = layer.tileRect(i), fill = color(i % layer.columns, i / layer.columns)
            let size = PixelRect(x: 0, y: 0, width: rect.width, height: rect.height)
            let tile = try made[size]?[fill] ?? PixelBuffer(width: size.width, height: size.height, fill: fill)
            made[size, default: [:]][fill] = tile
            layer.tiles[i] = tile
        }
        return layer
    }

    /// An opaque sRGB color (0...1 per channel) as a linear pixel, decoded the
    /// way an opened file's bytes are.
    private static func linear(_ srgb: [Float]) throws -> RGBA {
        let bytes = srgb.map { UInt8(min(max($0, 0), 1) * 255 + 0.5) } + [255]
        return try PixelBuffer(rgba8: bytes, width: 1, height: 1).pixel(x: 0, y: 0)
    }
}
