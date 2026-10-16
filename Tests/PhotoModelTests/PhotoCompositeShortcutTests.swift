// PhotoCompositeShortcutTests.swift: the two composites PhotoLayerComposite
// skips give the same pixels as CoreRaster's composite (#1636, PB-13). An
// opaque normal layer at opacity 1 that covers a picture tile replaces it,
// and a layer that paints only part of a tile is composited over just that
// part, in every blend mode. Each case is checked against one CoreRaster
// composite of the whole layer. Runs on Linux and macOS.
import CoreRaster
@testable import PhotoModel
import Testing

@Suite struct PhotoCompositeShortcutTests {
    private let size = PixelBuffer.tileSize

    @Test func anOpaqueNormalLayerReplacesTheTileBitForBit() throws {
        let below = try backdrop()
        var pixels = try PixelBuffer(width: size, height: size, fill: RGBA(r: 0.3, g: 0.6, b: 0.1, a: 1))
        try pixels.setPixel(x: 7, y: 9, RGBA(r: 0.9, g: 0.05, b: 0.4, a: 1))
        #expect(try PhotoLayerComposite.replaces(pixels, below, dx: 0, dy: 0, mode: .normal, opacity: 1))
        #expect(try composited(pixels, onto: below) == reference(pixels, onto: below))
        #expect(try composited(pixels, onto: below) == pixels)
    }

    @Test func onlyAnOpaqueCoveringNormalLayerAtFullOpacityReplaces() throws {
        let below = try backdrop()
        let opaque = try PixelBuffer(width: size, height: size, fill: RGBA(r: 0.3, g: 0.6, b: 0.1, a: 1))
        var holed = opaque
        try holed.setPixel(x: size - 1, y: size - 1, RGBA(r: 0.1, g: 0.1, b: 0.1, a: 0.5))
        #expect(try !PhotoLayerComposite.replaces(holed, below, dx: 0, dy: 0, mode: .normal, opacity: 1))
        #expect(try !PhotoLayerComposite.replaces(opaque, below, dx: 0, dy: 0, mode: .normal, opacity: 0.99))
        #expect(try !PhotoLayerComposite.replaces(opaque, below, dx: 0, dy: 0, mode: .multiply, opacity: 1))
        #expect(try !PhotoLayerComposite.replaces(opaque, below, dx: 1, dy: 0, mode: .normal, opacity: 1))
        #expect(try composited(holed, onto: below) == reference(holed, onto: below))
    }

    @Test func aPartlyPaintedLayerMatchesInEveryBlendMode() throws {
        let below = try backdrop()
        var pixels = try PixelBuffer(width: size, height: size)
        for (x, y) in [(40, 30), (41, 200), (180, 31), (90, 120)] {
            try pixels.setPixel(x: x, y: y, RGBA(r: 0.2, g: 0.05, b: 0.5, a: 0.7))
        }
        #expect(try PhotoLayerComposite.paintedRect(of: pixels) == PixelRect(x: 40, y: 30, width: 141, height: 171))
        for mode in BlendMode.allCases {
            let ours = try composited(pixels, onto: below, mode: mode, opacity: 0.6, offset: (13, -21))
            let whole = try reference(pixels, onto: below, mode: mode, opacity: 0.6, offset: (13, -21))
            #expect(ours == whole, "\(mode)")
        }
    }

    @Test func aClearLayerLeavesTheTileAndFindsNoPaint() throws {
        let below = try backdrop()
        let clear = try PixelBuffer(width: size, height: size)
        #expect(try PhotoLayerComposite.paintedRect(of: clear) == nil)
        #expect(try composited(clear, onto: below, mode: .screen, opacity: 0.6) == below)
    }

    /// One tile of mixed, partly transparent color.
    private func backdrop() throws -> PixelBuffer {
        var below = try PixelBuffer(width: size, height: size, fill: RGBA(r: 0.1, g: 0.4, b: 0.2, a: 0.8))
        try below.setPixel(x: 100, y: 60, RGBA(r: 0.5, g: 0.5, b: 0.5, a: 1))
        try below.setPixel(x: 0, y: 0, RGBA(r: 0, g: 0, b: 0, a: 0))
        return below
    }

    /// `pixels` as a layer at `offset`, through PhotoLayerComposite.
    private func composited(_ pixels: PixelBuffer, onto below: PixelBuffer, mode: BlendMode = .normal,
                            opacity: Double = 1, offset: (Int, Int) = (0, 0)) throws -> PixelBuffer {
        var layer = PhotoLayer(id: "top", name: "Top", opacity: opacity, blendMode: mode)
        layer.offsetX = offset.0
        layer.offsetY = offset.1
        return try PhotoLayerComposite.composite(
            LayerContent(layer: layer, pixels: TiledPixels(pixels)), onto: below, origin: (0, 0),
            adjusting: LiveAdjustmentLayers.make(), masking: LiveSelection.masking())
    }

    /// The whole layer onto `below` in one CoreRaster composite.
    private func reference(_ pixels: PixelBuffer, onto below: PixelBuffer, mode: BlendMode = .normal,
                           opacity: Double = 1, offset: (Int, Int) = (0, 0)) throws -> PixelBuffer {
        try CoreRaster.composite(pixels, onto: below, x: offset.0, y: offset.1, mode: mode, opacity: Float(opacity))
    }
}
