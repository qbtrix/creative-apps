// PhotoOrientationTests.swift (orientation-crop OC-11): Photo's Flip Canvas mirrors every layer
// with its offset and mask as one undo step, its turns and flips compose as the kernel's
// Orientation does, and its crop Swap sizes on the kernel's CropRules.
import CoreRaster
import FlareCore
import Foundation
@testable import PhotoModel
import SuiteKernel
import Testing

@Suite
struct PhotoOrientationTests {
    static let size = (w: 48, h: 32), patch = PixelRect(x: 6, y: 4, width: 16, height: 10)

    /// A 48 x 32 gradient, a 16 x 10 patch at (6, 4) above it with a gradient mask, and a selection.
    func twoLayers() throws -> PhotoWorkspace {
        var w = PhotoWorkspace(services: .live)
        var bg: [UInt8] = []
        for y in 0..<Self.size.h { for x in 0..<Self.size.w { bg += [UInt8(x * 5), UInt8(y * 7), 90, 255] } }
        try w.open(rgba8: bg, width: Self.size.w, height: Self.size.h, name: "two.png")
        var top: [UInt8] = [], mask: [UInt8] = []
        for y in 0..<10 {
            for x in 0..<16 { top += [250, UInt8(x * 15), UInt8(y * 25), 255]; mask += [UInt8(x * 16), UInt8(y * 20), 0, 255] }
        }
        w.paste(ClipboardImage(image: DecodedImage(rgba8: top, width: 16, height: 10), source: Self.patch),
                viewCenter: Mask.Point(x: 0, y: 0))
        let id = try #require(w.selectedLayerID)
        w.masks[id] = try TiledPixels(rgba8: mask, width: 16, height: 10)
        w.selection = PixelRect(x: 2, y: 3, width: 5, height: 4)
        return w
    }

    func flip(_ w: inout PhotoWorkspace, _ axis: String) throws {
        _ = try PhotoWorkspace.catalog.run("image.flip", params: .object(["axis": .string(axis)]), on: &w)
    }

    @Test func flipCanvasMirrorsBothLayersWithOffsetsAndMasks() throws {
        var w = try twoLayers()
        let id = try #require(w.selectedLayerID)
        let before = w, composite = try w.composite()
        try flip(&w, "horizontal")
        #expect(w.canvas == before.canvas)
        let layer = try #require(w.layers.first { $0.id == id })
        #expect(layer.offsetX == Self.size.w - (Self.patch.x + Self.patch.width) && layer.offsetY == Self.patch.y)
        let pixels = try #require(w.pixels[id]), was = try #require(before.pixels[id])
        let mask = try #require(w.masks[id]), wasMask = try #require(before.masks[id])
        for y in 0..<10 {
            for x in 0..<16 {
                #expect(try pixels.pixel(x: x, y: y) == was.pixel(x: 15 - x, y: y))
                #expect(try mask.pixel(x: x, y: y) == wasMask.pixel(x: 15 - x, y: y))
            }
        }
        let now = try w.composite()
        for y in 0..<Self.size.h {
            for x in 0..<Self.size.w { #expect(try now.pixel(x: x, y: y) == composite.pixel(x: Self.size.w - 1 - x, y: y)) }
        }
        #expect(w.selection == PixelRect(x: Self.size.w - 7, y: 3, width: 5, height: 4))
        #expect(w.lastGeometryChange?.change == .flippedCanvas(.horizontal))

        var v = before
        try flip(&v, "vertical")
        let down = try #require(v.layers.first { $0.id == id })
        #expect(down.offsetX == Self.patch.x && down.offsetY == Self.size.h - (Self.patch.y + Self.patch.height))
        let vm = try #require(v.masks[id])
        #expect(try vm.pixel(x: 3, y: 0) == wasMask.pixel(x: 3, y: 9))
    }

    /// Each sequence of turns and flips lands every pixel where the kernel's product sends it.
    @Test(arguments: [["cw", "h"], ["h", "cw"], ["ccw", "v"], ["180", "h", "cw"], ["v", "h"]])
    func turnsAndFlipsComposeAsTheKernelOrientation(_ steps: [String]) throws {
        var w = try twoLayers()
        let start = try w.composite()
        var o = Orientation.up
        for step in steps {
            switch step {
            case "h", "v":
                try flip(&w, step == "h" ? "horizontal" : "vertical")
                o = o.flipped(step == "h" ? .horizontal : .vertical)
            default:
                _ = try PhotoWorkspace.catalog.run("image.rotate-\(step)", params: .object([:]), on: &w)
                o = step == "180" ? o.rotated(clockwise: true).rotated(clockwise: true) : o.rotated(clockwise: step == "cw")
            }
        }
        let (nw, nh) = o.size(Self.size.w, Self.size.h)
        #expect(w.canvas == CanvasSize(width: nw, height: nh))
        let now = try w.composite()
        for y in 0..<Self.size.h {
            for x in 0..<Self.size.w {
                let unit = FlareCore.Point(x: (Double(x) + 0.5) / Double(Self.size.w), y: (Double(y) + 0.5) / Double(Self.size.h))
                let p = o.matrix.apply(unit)
                let tx = Int((p.x * Double(nw)).rounded(.down)), ty = Int((p.y * Double(nh)).rounded(.down))
                #expect(try now.pixel(x: tx, y: ty) == start.pixel(x: x, y: y))
            }
        }
    }

    @Test func aFlipIsOneUndoStep() throws {
        var w = try twoLayers()
        let id = try #require(w.selectedLayerID)
        let before = w, steps = w.historyIndex
        try flip(&w, "horizontal")
        #expect(w.historyIndex == steps + 1)
        #expect(w.undoActionName == "Undo Flip Horizontal")
        w.undo()
        #expect(w.historyIndex == steps)
        #expect(w.layers == before.layers && w.selection == before.selection)
        #expect(try w.pixels[id]?.pixel(x: 0, y: 0) == before.pixels[id]?.pixel(x: 0, y: 0))
        #expect(try w.masks[id]?.pixel(x: 0, y: 0) == before.masks[id]?.pixel(x: 0, y: 0))
    }

    /// RJ-P70: the job's flip of two-layers.ora exports the original PNG mirrored, pixel for pixel.
    @Test func flipCanvasRealJob() throws {
        struct Script: Decodable { var steps: [CommandEnvelope]; var atomic: Bool }
        let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("RealJobs/photo/flip-canvas")
        let script = try JSONDecoder().decode(Script.self, from: Data(contentsOf: folder.appendingPathComponent("flip-canvas.jobs.json")))
        var doc = try PhotoHeadless.open(Data(contentsOf: folder.appendingPathComponent("input/two-layers.ora")), name: "two-layers.ora")
        let original = try #require(doc.export("png", options: .object([:])).first)
        let report = PhotoHeadless.catalog.runBatch(script.steps, on: &doc, atomic: script.atomic)
        #expect(report.stoppedAt == nil, "\(report.steps.compactMap(\.error))")
        let a = try PhotoHeadless.codec.decode(original.data, longestSide: nil)
        let b = try PhotoHeadless.codec.decode(#require(doc.export("png", options: .object([:])).first).data, longestSide: nil)
        let want = try PhotoHeadless.codec.decode(Data(contentsOf: folder.appendingPathComponent("expected/two-layers.png")), longestSide: nil)
        #expect(b.width == a.width && b.height == a.height && b.rgba8 == want.rgba8)
        for y in 0..<a.height {
            for x in 0..<a.width {
                let i = (y * a.width + x) * 4, j = (y * a.width + a.width - 1 - x) * 4
                #expect(b.rgba8[i..<(i + 4)] == a.rgba8[j..<(j + 4)])
            }
        }
    }

    @Test func cropSwapTurnsTheFrameOnTheKernelRules() throws {
        var w = PhotoWorkspace(services: .live)
        try w.newCanvas(width: 800, height: 600)
        w.setCropAspect(.ratio(3, 2))
        let crop = try #require(w.pendingCrop)
        w.swapCropAspect()
        let want = CropRules.swapped(Rect(minX: Double(crop.x), minY: Double(crop.y), maxX: Double(crop.maxX), maxY: Double(crop.maxY)),
                                     in: Rect(minX: 0, minY: 0, maxX: 800, maxY: 600))
        let got = try #require(w.pendingCrop)
        #expect(w.cropAspect == .ratio(2, 3))
        #expect(abs(Double(got.x) - want.minX) <= 1 && abs(Double(got.y) - want.minY) <= 1)
        #expect(abs(Double(got.width) - want.width) <= 1 && abs(Double(got.height) - want.height) <= 1)
    }
}
