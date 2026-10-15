// PhotoCompositeCostTests.swift: one layer's composite costs its own pixels,
// not a copy of the whole picture per layer tile. CoreRaster's composite
// gives back a fresh copy of its backdrop, so compositing tile by tile onto
// the whole picture copied it once per tile: Merge Down of two 12 MP layers
// took about a minute. A one-pixel-tall layer 16 tiles wide over a 64 MB
// picture now costs about one copy of that picture (the result), where it
// cost 16. The tiled path Merge Down and Flatten use gives the same pixels
// as the picture path, blend, opacity and an offset that straddles the
// picture's tiles included. Runs on Linux and macOS.
import CoreRaster
@testable import PhotoModel
import Testing

@Suite struct PhotoCompositeCostTests {
    @Test func aLayerCostsAboutOnePictureCopyNotOnePerTile() throws {
        let picture = try PixelBuffer(width: 4096, height: 1024, fill: RGBA(r: 0.2, g: 0.3, b: 0.4, a: 1))
        let strip = try TiledPixels(width: 4096, height: 1, fill: RGBA(r: 0.5, g: 0.1, b: 0.1, a: 0.5))
        #expect(strip.tiles.count == 16)
        let content = LayerContent(layer: PhotoLayer(id: "strip", name: "Strip"), pixels: strip)
        let clock = ContinuousClock()
        var copies: [Double] = [], composites: [Double] = []
        for _ in 0..<5 {
            // One copy of the picture: the copy-on-write a first write makes.
            var copy = picture
            copies.append(clock.measure { try? copy.setPixel(x: 0, y: 0, .clear) } / .milliseconds(1))
            composites.append(clock.measure {
                _ = try? PhotoLayerComposite.composite(
                    content, onto: picture, origin: (0, 0),
                    adjusting: LiveAdjustmentLayers.make(), masking: LiveSelection.masking())
            } / .milliseconds(1))
        }
        let (copy, composite) = (median(copies), median(composites))
        // A 2 ms floor keeps a fast copy from turning scheduling noise into a ratio.
        #expect(composite <= 4 * max(copy, 2), "composite \(composite) ms, one picture copy \(copy) ms")
    }

    @Test func theTiledPathMatchesThePicturePath() throws {
        var below = try PixelBuffer(width: 600, height: 520, fill: RGBA(r: 0.1, g: 0.4, b: 0.2, a: 0.8))
        try below.setPixel(x: 300, y: 260, RGBA(r: 0.5, g: 0.5, b: 0.5, a: 1))
        var layer = PhotoLayer(id: "top", name: "Top", opacity: 0.6, blendMode: .screen)
        layer.offsetX = -37
        layer.offsetY = 101
        var pixels = try PixelBuffer(width: 530, height: 400, fill: RGBA(r: 0.3, g: 0.05, b: 0.6, a: 0.7))
        try pixels.setPixel(x: 260, y: 150, RGBA(r: 0.9, g: 0.9, b: 0, a: 0.9))
        let content = LayerContent(layer: layer, pixels: TiledPixels(pixels))
        let (adjusting, masking) = (LiveAdjustmentLayers.make(), LiveSelection.masking())
        let flat = try PhotoLayerComposite.composite(
            content, onto: below, origin: (20, -10), adjusting: adjusting, masking: masking)
        let tiled = try PhotoLayerComposite.composite(
            content, onto: TiledPixels(below), origin: (20, -10), adjusting: adjusting, masking: masking)
        #expect(flat != below)
        #expect(try tiled.flattened() == flat)
        // The whole layer onto the picture in one CoreRaster composite.
        let reference = try CoreRaster.composite(
            pixels, onto: below, x: -37 - 20, y: 101 + 10, mode: .screen, opacity: Float(layer.opacity))
        #expect(flat == reference)
    }
}

private func median(_ values: [Double]) -> Double {
    let sorted = values.sorted()
    return sorted.isEmpty ? 0 : sorted[sorted.count / 2]
}
