// PhotoCompositeCostTests.swift: one layer's composite costs its own pixels,
// not a copy of the whole picture per layer tile. CoreRaster's composite
// gives back a fresh copy of its backdrop, so compositing tile by tile onto
// the whole picture copied it once per tile: Merge Down of two 12 MP layers
// took about a minute. The cost test compares two composites onto the same
// 64 MB picture, a one-pixel strip 16 tiles wide and one a single tile wide,
// so it measures the per-tile copy, not the machine: both pay one picture
// copy (the result), and the old loop made the wide strip pay 16. The bound
// is 8x, half those 16 copies: the fixed code measures 1.2-1.5x on Linux and
// about 4.6x on the macOS runner under parallel test load, and the old loop
// measured 16.2x. The suite is serialized and each strip takes the fastest
// of nine runs, so scheduler stalls drop out. The tiled
// path Merge Down and Flatten use gives the same pixels as the picture path,
// blend, opacity and an offset that straddles the picture's tiles included.
// Runs on Linux and macOS.
import CoreRaster
@testable import PhotoModel
import Testing

@Suite(.serialized) struct PhotoCompositeCostTests {
    @Test func aLayerCostsAboutOnePictureCopyNotOnePerTile() throws {
        let picture = try PixelBuffer(width: 4096, height: 1024, fill: RGBA(r: 0.2, g: 0.3, b: 0.4, a: 1))
        let fill = RGBA(r: 0.5, g: 0.1, b: 0.1, a: 0.5)
        let wide = try TiledPixels(width: 4096, height: 1, fill: fill)
        let narrow = try TiledPixels(width: PixelBuffer.tileSize, height: 1, fill: fill)
        #expect(wide.tiles.count == 16)
        #expect(narrow.tiles.count == 1)
        let wideCost = try fastest(of: 9) { try composite(wide, onto: picture) }
        let narrowCost = try fastest(of: 9) { try composite(narrow, onto: picture) }
        // Both pay one picture copy; the per-tile loop made the wide strip pay
        // 16 (measured 16.2x). 8x is half of that, above the ~4.6x the fixed
        // code shows on a loaded macOS runner. The 1 ms floor guards a machine
        // so fast the narrow run rounds to nothing.
        #expect(wideCost <= 8 * max(narrowCost, 1),
                "16-tile strip \(wideCost) ms, 1-tile strip \(narrowCost) ms")
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

/// `strip` (a pixel layer at the canvas origin) composited onto `picture`.
private func composite(_ strip: TiledPixels, onto picture: PixelBuffer) throws {
    let content = LayerContent(layer: PhotoLayer(id: "strip", name: "Strip"), pixels: strip)
    _ = try PhotoLayerComposite.composite(
        content, onto: picture, origin: (0, 0),
        adjusting: LiveAdjustmentLayers.make(), masking: LiveSelection.masking())
}

/// The fastest of `runs` timings of `work`, in milliseconds: noise only adds time.
private func fastest(of runs: Int, _ work: () throws -> Void) throws -> Double {
    let clock = ContinuousClock()
    var best = Double.infinity
    for _ in 0..<runs {
        var failure: (any Error)?
        let time = clock.measure {
            do { try work() } catch { failure = error }
        } / .milliseconds(1)
        if let failure { throw failure }
        best = min(best, time)
    }
    return best
}
