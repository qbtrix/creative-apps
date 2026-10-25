// HaloFramePNGCoreTests.swift (shared-codecs SC-5, MJ-SC-halo): HaloHeadless' PNG is CoreRaster's `PNG.write` bytes
// for the rendered frame, named by the frame asked for, and it decodes back to that frame: straight 8-bit sRGB RGBA
// equal to the frame's `rgba8()`, and through core's `PNG.read` within one level. A 50% opaque solid keeps alpha 128
// and its full red, so a premultiplied write fails. Linux-safe.
import CoreRaster
import Foundation
@testable import HaloModel
import SuiteKernel
import Testing

@Suite struct HaloFramePNGCoreTests {
    /// A headless document whose one selected 40 × 20 composition is a 50% opaque orange solid over nothing.
    static func halfOpaque() -> HaloHeadless {
        let solid = HaloLayer(
            id: "comp-1-layer-1", name: "Half", kind: .solid, inFrame: 0, outFrame: 1,
            color: HaloLayerColor(red: 1, green: 0.5, blue: 0), opacity: 0.5)
        let comp = HaloComposition(
            id: "comp-1", name: "Alpha", width: 40, height: 20, framesPerSecond: 24, durationFrames: 1, layers: [solid])
        let state = HaloDocumentState(compositions: [comp], selectedCompositionID: comp.id, nextLayerNumber: 2)
        return HaloHeadless(workspace: HaloProject(services: .live, document: state))
    }

    /// The largest difference, in 8-bit levels, between two equal-length byte runs.
    static func worst(_ a: [UInt8], _ b: [UInt8]) -> Int {
        zip(a, b).map { abs(Int($0) - Int($1)) }.max() ?? 0
    }

    @Test func exportIsCorePNGWriteOfTheAskedFrame() throws {
        var doc = try HaloHeadless.open(HaloHeadlessTests.input("render-frame", "shapes.halo"), name: "shapes.halo")
        _ = try HaloHeadless.catalog.run("timeline.scrub", params: .object(["frame": .number(12)]), on: &doc)
        let options: JSONValue = .object(["frame": .number(5)])
        let file = try #require(try doc.export("png", options: options).first)
        let rendered = try doc.renderFrame(options)
        #expect(rendered.frame == 5)
        #expect(file.suggestedName == "Shapes-5.png")
        #expect(file.format == "png")
        #expect(file.data == (try PNG.write(rendered.pixels)))
        let info = try PNG.info(file.data)
        #expect(info.width == 64 && info.height == 36)
        #expect(info.bitDepth == 8 && info.colorType == 6)
        #expect(!info.interlaced)
    }

    @Test func exportDecodesToTheRenderedFrame() throws {
        var doc = try HaloHeadless.open(HaloHeadlessTests.input("render-frame", "shapes.halo"), name: "shapes.halo")
        _ = try HaloHeadless.catalog.run("timeline.scrub", params: .object(["frame": .number(12)]), on: &doc)
        let data = try #require(try doc.export("png", options: .object([:])).first).data
        let expected = try doc.renderFrame(.object([:])).pixels.rgba8()
        let png = try HaloJob.decodePNG(data)
        #expect(png.width == 64 && png.height == 36)
        #expect(png.rgba == expected)
        let read = try PNG.read(data).rgba8()
        #expect(read.count == expected.count)
        #expect(Self.worst(read, expected) <= 1)
    }

    @Test func halfOpaqueFrameKeepsStraightAlpha() throws {
        let doc = Self.halfOpaque()
        let file = try #require(try doc.export("png", options: .object([:])).first)
        #expect(file.suggestedName == "Alpha-0.png")
        let expected = try doc.renderFrame(.object([:])).pixels.rgba8()
        let png = try HaloJob.decodePNG(file.data)
        #expect(png.rgba.count == 40 * 20 * 4)
        #expect(png.rgba == expected)
        let alphas = stride(from: 3, to: png.rgba.count, by: 4).map { png.rgba[$0] }
        #expect(alphas.allSatisfy { $0 == 128 }, "alpha values \(Set(alphas))")
        // Straight, not premultiplied: full red stays near 255, not near half.
        #expect(png.rgba.first.map { $0 > 200 } == true, "red \(String(describing: png.rgba.first))")
        #expect(Self.worst(try PNG.read(file.data).rgba8(), expected) <= 1)
    }
}
