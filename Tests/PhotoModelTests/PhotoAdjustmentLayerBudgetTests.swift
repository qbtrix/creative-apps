// PhotoAdjustmentLayerBudgetTests.swift: PB-13 of photo-adjustment-layers
// (AL-4), the model step of an adjustment drag on an adjustment layer. The
// stack is three layers on `PhotoWorkspace()` (.live): a white Background
// with a red block, an Exposure layer above it, and a blue block screened at
// 60 % at the top, on a 256 x 256 canvas, so the whole-canvas damage an
// `adjustLayer` makes is one 256 px tile. One event is one `adjustLayer`
// Exposure change plus the render of the tiles it damaged (exactly one), so
// 60 events of one slider gesture are timed, then `endAdjustLayer` makes them
// one undo step. As in PhotoBudgetTests the median is gated at 4 ms in a
// release build (`swift test -c release -Xswiftc -enable-testing --filter
// PhotoAdjustmentLayerBudgetTests`, which `@testable` needs for the tile
// render) and only reported in debug, where CoreRaster's per-pixel loops run
// about 20 times slower. Every build prints p50, p95 and max, and a series
// with fewer than 60 samples fails. Runs on Linux and macOS.
import CoreRaster
@testable import PhotoModel
import Testing

#if DEBUG
/// Debug reports the medians; it gates only the sample count.
private let gated = false
#else
private let gated = true
#endif

/// Adjustment events timed per series.
private let events = 60

@Suite struct PhotoAdjustmentLayerBudgetTests {
    @Test func exposureDragOnLayer() throws {
        let (start, id) = try stack()
        var workspace = start
        let canvas = try #require(workspace.canvas)
        let before = try workspace.rendered(canvas.rect)
        let clock = ContinuousClock()
        var costs: [Duration] = []
        costs.reserveCapacity(events)
        for event in 1...events {
            let shown = workspace.revision
            var tiles: [PixelRect] = []
            let cost = try clock.measure {
                workspace.adjustLayer(id, .exposure(Float(event) * 0.02))
                tiles = PhotoRenderer.tiles(of: canvas, in: workspace.damage(since: shown))
                for tile in tiles { _ = try workspace.rendered(tile) }
            }
            #expect(tiles.count == 1, "event \(event) damaged \(tiles.count) tiles, one expected")
            if tiles.count == 1 { costs.append(cost) }
        }
        workspace.endAdjustLayer()
        #expect(workspace.undoActionName == "Undo Exposure")
        #expect(try workspace.rendered(canvas.rect) != before, "the exposure drag changed the picture")
        let series = Series(name: "PB-13 exposure on a layer", costs: costs)
        #expect(series.samples >= events, "\(series.name): \(series.samples) samples, \(events) needed")
        if gated { #expect(series.p50 <= .milliseconds(4), "\(series.name): median \(series.p50)") }
    }

    /// The 256 x 256 Background with a red block, an Exposure layer above it,
    /// and a blue block screened at 60 % at the top: a 3-layer stack.
    private func stack() throws -> (PhotoWorkspace, adjustment: PhotoLayer.ID) {
        var workspace = try whiteImage(PixelBuffer.tileSize, PixelBuffer.tileSize)
        workspace.setToolOption(.color(red: 200, green: 30, blue: 40))
        stroke(&workspace, .marquee, from: point(20, 30), to: point(180, 220))
        workspace.fillSelection()
        workspace.deselect()
        workspace.addLayer()
        workspace.setToolOption(.color(red: 20, green: 90, blue: 230))
        stroke(&workspace, .marquee, from: point(100, 60), to: point(240, 250))
        workspace.fillSelection()
        workspace.deselect()
        let top = try #require(workspace.selectedLayerID)
        workspace.setBlendMode(top, .screen)
        workspace.setOpacity(top, percent: 60)
        workspace.selectLayer(try #require(workspace.layers.last?.id))
        workspace.addAdjustmentLayer(.exposure)
        let id = try #require(workspace.selectedLayerID)
        #expect(workspace.layers.map(\.id).firstIndex(of: id) == 1, "the Exposure layer sits in the middle")
        #expect(workspace.layers.count == 3)
        return (workspace, id)
    }
}

/// A timed series, sorted, printed once with its p50, p95 and max.
private struct Series {
    let name: String, samples: Int, p50: Duration, p95: Duration, max: Duration

    init(name: String, costs: [Duration]) {
        let sorted = costs.sorted()
        self.name = name
        samples = sorted.count
        p50 = sorted.isEmpty ? .zero : sorted[sorted.count / 2]
        p95 = sorted.isEmpty ? .zero : sorted[sorted.count * 95 / 100]
        max = sorted.last ?? .zero
        print("PhotoBudget \(name) p50 \(ms(p50)) ms p95 \(ms(p95)) ms max \(ms(max)) ms (\(samples) events, \(gated ? "gated" : "report only"))")
    }
}

private func ms(_ duration: Duration) -> Double { (duration / .milliseconds(1) * 10_000).rounded() / 10_000 }
