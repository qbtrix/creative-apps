// PhotoFixtures.swift: the documents of blueprint 4.4, built in code on the
// `.fake` services, never read from disk, for `-PhotoFixture` (S-12), the
// journeys and the model tests. `empty` has no image; `sample` is the UI
// tests' test photo (800 x 600, a sky gradient from blue at the top to orange
// at the bottom, a yellow sun disc centered at (560, 220), radius 90);
// `layered` is `sample` under a "Curves 1" adjustment layer and a masked
// "Paint" layer (a red stroke, Multiply, 60%); `large` is 4000 x 3000 in
// three layers of gradients and noise, built from shared one-color tiles so it
// costs a few buffers, not 12 M pixels each; `stress` is 3840 x 2160 in 100
// layers (pixel layers, a third of them masked, and every fourth an
// adjustment layer), each pixel layer painting a sparse diagonal of tiles from
// one shared tile cache, for the real-app stress journeys. The blueprint's test-only
// `limit` (about 4 GB) is left out. Each fixture opens with a clean history.
// PhotoLaunchOptions reads `-PhotoFixture <name>` from the arguments the app
// passes in (the window's size comes from SuiteUI's `-SuiteWindowSize`);
// `launch(_:)` builds the window's workspace from them (S-12), and
// `isPreviewData` tells the status line to show its "Preview data" pill.
// Linux-safe.
import CoreRaster

/// A built-in document (blueprint 4.4).
public enum PhotoFixture: String, CaseIterable, Sendable {
    case empty, sample, layered, large, stress
}

/// The launch arguments a Photo window reads (S-12).
public struct PhotoLaunchOptions: Equatable, Sendable {
    /// `-PhotoFixture <name>` when the name is a fixture.
    public var fixture: PhotoFixture?
    /// `-PhotoFixture <name>` when the name isn't one.
    public var unknownFixture: String?

    /// Reads the flags anywhere in `arguments`; a flag with no value after it is ignored.
    public init(arguments: [String]) {
        var rest = arguments[...]
        while let argument = rest.popFirst() {
            switch argument {
            case "-PhotoFixture":
                guard let name = rest.popFirst() else { break }
                fixture = PhotoFixture(rawValue: name)
                unknownFixture = fixture == nil ? name : nil
            default: break
            }
        }
    }
}

extension PhotoWorkspace {
    /// The workspace a window opens with: the fixture on `.fake`, an empty
    /// `.fake` workspace saying "No fixture named <name>." for an unknown
    /// name, and nil without `-PhotoFixture`, so the window stays on `.live`.
    public static func launch(_ options: PhotoLaunchOptions) -> PhotoWorkspace? {
        if let name = options.fixture {
            if let workspace = try? fixture(name) { return workspace }
            var workspace = PhotoWorkspace(services: .fake)
            workspace.statusMessage = "The \(name.rawValue) fixture couldn't be built."
            return workspace
        }
        guard let unknown = options.unknownFixture else { return nil }
        var workspace = PhotoWorkspace(services: .fake)
        workspace.statusMessage = "No fixture named \(unknown)."
        return workspace
    }

    /// The workspace runs on the fakes (`-PhotoFixture`), not the user's
    /// files: the status line shows a "Preview data" pill.
    public var isPreviewData: Bool { services.archive is FakeArchive }

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
        case .stress: try workspace.openStress()
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
        // One kind per layer, as addAdjustmentLayer makes it.
        for other in AdjustmentKind.allCases where other != .curves { curves.apply(.setEnabled(other, false)) }
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

    /// 100 layers at 3840 x 2160, top first: 99 above "Background" (a
    /// top-to-bottom ramp). Layer n (1 at the bottom) is an adjustment layer
    /// when n is a multiple of 4 (Exposure, Levels, Curves, Hue/Saturation in
    /// turn, each a mild setting), else a pixel layer "Layer n" painting the
    /// tiles where (column + row + n) % 10 == 0 in a translucent color, at 80%
    /// opacity, with a mask hiding its right half when n is a multiple of 3.
    /// Every tile comes from one cache, so the 99 layers share a few buffers.
    /// The top layer, a pixel layer, is selected, so Adjust edits the image.
    private mutating func openStress() throws {
        let width = 3840, height = 2160
        var made: [PixelRect: [RGBA: PixelBuffer]] = [:]
        let background = try Self.tiled(width: width, height: height, made: &made) { _, row in
            RGBA(r: 0.1 + Float(row) * 0.08, g: 0.3, b: 0.9 - Float(row) * 0.08, a: 1)
        }
        start(with: background, name: "stress.png")
        let colors = [RGBA(r: 0.9, g: 0.3, b: 0.2, a: 0.5), RGBA(r: 0.2, g: 0.8, b: 0.4, a: 0.5),
                      RGBA(r: 1, g: 1, b: 1, a: 0.4)].map { $0.premultiplied() }
        let kinds: [AdjustmentKind] = [.exposure, .levels, .curves, .hueSaturation]
        let white = RGBA(r: 1, g: 1, b: 1, a: 1), black = RGBA(r: 0, g: 0, b: 0, a: 1)
        for n in 1..<100 {
            if n.isMultiple(of: 4) {
                let kind = kinds[(n / 4) % kinds.count]
                var settings = AdjustmentSettings()
                for other in AdjustmentKind.allCases where other != kind { settings.apply(.setEnabled(other, false)) }
                switch kind {
                case .exposure: settings.apply(.exposure(0.1))
                case .levels: settings.apply(.blackPoint(0.02))
                case .curves: settings.apply(.curvePoints([CurvePoint(x: 0, y: 0), CurvePoint(x: 0.5, y: 0.55), CurvePoint(x: 1, y: 1)]))
                case .hueSaturation, .blur: break
                }
                selectedLayerID = insertLayer(named: "\(kind.title) \(n / 4)", pixels: nil, kind: .adjustment(settings), at: 0)
                continue
            }
            let paint = try Self.tiled(width: width, height: height, made: &made) { column, row in
                (column + row + n) % 10 == 0 ? colors[n % colors.count] : .clear
            }
            let id = insertLayer(named: "Layer \(n)", pixels: paint, kind: .pixels, at: 0)
            selectedLayerID = id
            guard let at = index(of: id) else { continue }
            layers[at].opacity = 0.8
            if n.isMultiple(of: 3) {
                layers[at].hasMask = true
                masks[id] = try Self.tiled(width: width, height: height, made: &made) { column, _ in
                    column < 8 ? white : black
                }
            }
        }
        touch(.all)
    }

    /// `width` x `height` pixels where each tile is one color, by its column
    /// and row; tiles of one size and color share one buffer.
    private static func tiled(width: Int, height: Int, color: (Int, Int) -> RGBA) throws -> TiledPixels {
        var made: [PixelRect: [RGBA: PixelBuffer]] = [:]
        return try tiled(width: width, height: height, made: &made, color: color)
    }

    /// `tiled`, sharing the buffers in `made` with earlier calls.
    private static func tiled(
        width: Int, height: Int, made: inout [PixelRect: [RGBA: PixelBuffer]], color: (Int, Int) -> RGBA
    ) throws -> TiledPixels {
        var layer = try TiledPixels(width: width, height: height)
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
