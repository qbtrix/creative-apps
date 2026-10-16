// PhotoAdjustmentLayerLatencyTests.swift: PB-13 of photo-adjustment-layers
// (AL-4), how long one Exposure slider event on an adjustment layer takes to
// become a picture the canvas can draw, done the way the window does it and
// timed the way PhotoBrushLatencyTests times a brush event. The stack is the
// one PhotoAdjustmentLayerBudgetTests times: a 256 x 256 white Background with
// a red block, an Exposure layer above it, and a blue block screened at 60 %
// at the top. The window's `model.adjustLayer(...)` goes through SwiftUI's
// State, so each event mutates a copy and writes it back (as StateBox does
// for a drag); PhotoRenderer.update then renders the tile batch the event
// damaged and CanvasTiles.apply makes its images. 61 events of one gesture,
// each rendered before the next; the first is untimed. The test prints p50
// and p95 as one ADJUSTMENT-LAYER-LATENCY line and writes it to
// .build/snapshots/photo-adjustment-layer-latency.txt. Release p50 within
// 8 ms per tile batch; debug (CI's `swift test`) reports it. Fewer than 60
// samples fails. macOS only.
import CoreRaster
import Foundation
import PhotoModel
import Testing

@testable import PhotoApp

@Suite struct PhotoAdjustmentLayerLatencyTests {
    #if DEBUG
    static let config = "debug"
    #else
    static let config = "release"
    #endif
    static let totalBudget: Double? = config == "release" ? 8 : nil

    @MainActor @Test func anExposureEventOnAnAdjustmentLayerBecomesAFrameWithinBudget() async throws {
        let clock = ContinuousClock()
        let (start, id) = try stack()
        var held = start
        let tiles = CanvasTiles()
        var shown = try await PhotoRenderer.update(held, since: nil).revision

        var total: [Double] = []
        for event in 0...60 {
            let t0 = clock.now
            var model = held
            model.adjustLayer(id, .exposure(Float(event + 1) * 0.02))
            held = model
            let next = try await PhotoRenderer.update(held, since: shown)
            tiles.apply(next)
            let t1 = clock.now
            #expect(tiles.handedBytes == next.tiles.reduce(0) { $0 + $1.rgba8.count })
            shown = next.revision
            guard event > 0 else { continue }
            #expect(!next.tiles.isEmpty, "exposure event \(event) damaged no tile")
            total.append(milliseconds(t1 - t0))
        }
        var model = held
        model.endAdjustLayer()
        held = model
        #expect(held.undoActionName == "Undo Exposure")

        let report = [
            "ADJUSTMENT-LAYER-LATENCY config=\(Self.config) canvas=256x256 layers=3 events=\(total.count)",
            "ms per tile batch: total p50 \(format(percentile(total, 0.5))) p95 \(format(percentile(total, 0.95))) |",
            "budget p50 total <= \(Self.totalBudget.map(format) ?? "report only (debug)")",
        ].joined(separator: " ")
        print(report)
        let folder = try packageRoot().appending(path: ".build/snapshots")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data((report + "\n").utf8).write(to: folder.appending(path: "photo-adjustment-layer-latency.txt"))

        #expect(total.count >= 60, "\(report)")
        if let budget = Self.totalBudget { #expect(percentile(total, 0.5) <= budget, "\(report)") }
    }

    /// The Background with a red block, an Exposure layer above it, and a
    /// blue block screened at 60 % at the top, on one 256 px tile.
    private func stack() throws -> (PhotoWorkspace, PhotoLayer.ID) {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: PixelBuffer.tileSize, height: PixelBuffer.tileSize)
        fill(&workspace, red: 200, green: 30, blue: 40, from: Mask.Point(x: 20, y: 30), to: Mask.Point(x: 180, y: 220))
        workspace.addLayer()
        fill(&workspace, red: 20, green: 90, blue: 230, from: Mask.Point(x: 100, y: 60), to: Mask.Point(x: 240, y: 250))
        let top = try #require(workspace.selectedLayerID)
        workspace.setBlendMode(top, .screen)
        workspace.setOpacity(top, percent: 60)
        workspace.selectLayer(try #require(workspace.layers.last?.id))
        workspace.addAdjustmentLayer(.exposure)
        let id = try #require(workspace.selectedLayerID)
        #expect(workspace.layers.count == 3)
        #expect(workspace.layers.map(\.id).firstIndex(of: id) == 1, "the Exposure layer sits in the middle")
        return (workspace, id)
    }

    /// Fills a marquee from `a` to `b` on the selected layer with one color.
    private func fill(_ workspace: inout PhotoWorkspace, red: UInt8, green: UInt8, blue: UInt8,
                      from a: Mask.Point, to b: Mask.Point) {
        workspace.setToolOption(.color(red: red, green: green, blue: blue))
        workspace.selectTool(.marquee)
        workspace.drag(from: a, to: a)
        workspace.drag(from: a, to: b)
        workspace.endDrag()
        workspace.fillSelection()
        workspace.deselect()
    }
}
