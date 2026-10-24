// PhotoNewImageTests.swift (document-setup DS-7, turned on by DS-8): file.new takes the shared DocumentSetup, so
// the image comes out at the size, resolution and background asked for: 4 × 6 in at 300 ppi on transparent is
// 1200 × 1800 with alpha 0, not 1920 × 1080 white or 4 × 6 px.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import SuiteKernel
import Testing
@testable import PhotoModel

struct PhotoNewImageTests {
    /// Runs file.new with `params` on a fresh workspace.
    static func made(_ params: [String: JSONValue]) throws -> PhotoWorkspace {
        var ws = PhotoWorkspace(services: .fake)
        _ = try PhotoWorkspace.catalog.run("file.new", params: .object(params), on: &ws)
        return ws
    }

    /// The Background layer's pixel at (x, y).
    static func pixel(_ ws: PhotoWorkspace, _ x: Int, _ y: Int) throws -> RGBA {
        let id = try #require(ws.layers.first?.id)
        return try #require(ws.pixels[id]).pixel(x: x, y: y)
    }

    static let print: [String: JSONValue] = ["width": .number(4), "height": .number(6), "unit": .string("in"),
                                             "resolution": .number(300), "background": .string("transparent")]

    @Test func fourBySixInchesAt300IsTransparent1200By1800() throws {
        let ws = try Self.made(Self.print)
        #expect(ws.canvas == CanvasSize(width: 1200, height: 1800))
        #expect(try Self.pixel(ws, 0, 0).a == 0)
        #expect(try Self.pixel(ws, 1199, 1799).a == 0)
        #expect(ws.resolution == 300)
    }

    @Test func aBareSizeIsWhitePixels() throws {
        let ws = try Self.made(["width": .number(24), "height": .number(18)])
        #expect(ws.canvas == CanvasSize(width: 24, height: 18))
        #expect(try Self.pixel(ws, 3, 3) == RGBA(r: 1, g: 1, b: 1, a: 1))
        #expect(ws.resolution == 72)
    }

    @Test func aPlainNewCanvasIsBackAt72() throws {
        var ws = try Self.made(Self.print)
        try ws.newCanvas(width: 8, height: 8)
        #expect(ws.resolution == 72)
    }

    @Test func thePrintPresetIsFourBySixInchesAt300() throws {
        let preset = try #require(PhotoWorkspace.newImagePresets.first { $0.id == "photo.print-4x6" })
        #expect(preset.parameters["unit"] == "in" && preset.parameters["resolution"] == "300")
        #expect(PhotoWorkspace.newImagePresets.allSatisfy { $0.app == .photo })
    }

    @Test func aHexBackgroundFillsWithThatColor() throws {
        let ws = try Self.made(["width": .number(8), "height": .number(8), "background": .string("#FF0000")])
        let p = try Self.pixel(ws, 4, 4)
        #expect(p.r == 1 && p.g == 0 && p.b == 0 && p.a == 1)
    }

    @Test func aSizePastTheLimitIsRefusedAndKeepsTheImage() throws {
        var ws = try Self.made(["width": .number(8), "height": .number(8)])
        #expect(throws: (any Error).self) {
            _ = try PhotoWorkspace.catalog.run("file.new", params: .object(["width": .number(20_000), "height": .number(10)]), on: &ws)
        }
        #expect(ws.canvas == CanvasSize(width: 8, height: 8))
    }
}
