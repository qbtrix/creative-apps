// PhotoAdjustTests.swift (adjust-everywhere AJ-8): Photo's workspace as the
// suite's AdjustTarget, through the adjust commands. A filter rewrites only the
// selected pixel layer, only inside the selection, as one undo step; Black &
// White and Invert are kinds of the image and of an adjustment layer and
// render; a look applies and saves; the kinds round-trip through a document
// and a file without them saves as before. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import SuiteImaging
import SuiteKernel
import Testing

@testable import PhotoModel

@Suite struct PhotoAdjustTests {
    /// The suite's adjust commands on Photo; PhotoWorkspace.catalog lists them too.
    static let catalog = (try? CommandCatalog<PhotoWorkspace>(app: "photo", AdjustCommands.specs(PhotoWorkspace.self),
                                                              history: { $0.history.kernel })) ?? .empty(app: "photo")

    /// A 16 x 12 checkerboard of 2 px squares, one "Background" layer, on `.fake`.
    static func checker() throws -> PhotoWorkspace {
        var bytes: [UInt8] = []
        for y in 0..<12 {
            for x in 0..<16 {
                let v: UInt8 = (x / 2 + y / 2) % 2 == 0 ? 230 : 20
                bytes += [v, 255 - v, v / 2, 255]
            }
        }
        var ws = PhotoWorkspace(services: .fake)
        try ws.open(rgba8: bytes, width: 16, height: 12, name: "checker.png")
        return ws
    }

    static let weights: JSONValue = .object(["red": .number(40), "yellow": .number(60), "green": .number(40),
                                             "cyan": .number(60), "blue": .number(20), "magenta": .number(80)])

    static func run(_ id: String, _ params: [String: JSONValue] = [:], on ws: inout PhotoWorkspace) throws {
        _ = try catalog.run(id, params: .object(params), on: &ws)
    }

    static func layerPixels(_ ws: PhotoWorkspace, _ id: PhotoLayer.ID) throws -> PixelBuffer {
        try #require(ws.pixels[id]).flattened()
    }

    @Test func aFilterRewritesTheSelectedLayerAndNoOther() throws {
        var ws = try Self.checker()
        let bottom = try #require(ws.layers.last).id
        ws.duplicateSelectedLayer()
        let top = try #require(ws.selectedLayerID)
        // The top copy loses its left half, so it differs from the composite.
        ws.setSelection(PixelRect(x: 0, y: 0, width: 8, height: 12))
        ws.deleteSelection()
        ws.setSelection(nil)
        let before = try Self.layerPixels(ws, top), under = try Self.layerPixels(ws, bottom)
        try Self.run("filter.gaussian-blur", ["radius": .number(2)], on: &ws)
        #expect(try Self.layerPixels(ws, bottom) == under, "the layer under changed")
        let want = try FilterRules.apply(.gaussianBlur(radius: 2), to: before, coverage: nil)
        #expect(try Self.layerPixels(ws, top) == want, "the layer isn't its own pixels blurred")
    }

    @Test func aFilterStaysInsideTheSelectionAsOneStep() throws {
        var ws = try Self.checker()
        let id = try #require(ws.selectedLayerID)
        ws.setSelection(PixelRect(x: 0, y: 0, width: 8, height: 12))
        let before = try Self.layerPixels(ws, id), steps = ws.historySteps.count
        try Self.run("filter.gaussian-blur", ["radius": .number(2)], on: &ws)
        let after = try Self.layerPixels(ws, id)
        var inside = 0
        for y in 0..<12 {
            for x in 0..<16 {
                let (a, b) = (try before.pixel(x: x, y: y), try after.pixel(x: x, y: y))
                if x >= 8 { #expect(a == b, "(\(x), \(y)) outside the selection changed") } else if a != b { inside += 1 }
            }
        }
        #expect(inside > 0, "nothing inside the selection changed")
        #expect(ws.historySteps.count == steps + 1)
        #expect(ws.undoActionName == "Undo Gaussian Blur")
        ws.undo()
        #expect(try Self.layerPixels(ws, id) == before)
    }

    @Test func filtersSayWhyTheyCantRun() throws {
        let empty = PhotoWorkspace(services: .fake)
        #expect(Self.catalog.availability("filter.gaussian-blur", on: empty).why == "Open an image first.")
        #expect(Self.catalog.availability("adjust.invert", on: empty).why == "Open an image first.")
        var ws = try Self.checker()
        #expect(Self.catalog.availability("filter.sharpen", on: ws) == .available)
        ws.addAdjustmentLayer(.curves)
        #expect(Self.catalog.availability("filter.sharpen", on: ws).why == "Select an image layer to filter it.")
        #expect(throws: CatalogError.self) { try Self.run("filter.gaussian-blur", ["radius": .number(2)], on: &ws) }
    }

    @Test func invertAndBlackAndWhiteAreKindsOfTheImage() throws {
        var ws = try Self.checker()
        let plain = try ws.composite()
        try Self.run("adjust.invert", on: &ws)
        #expect(ws.adjustments.kinds == [.invert])
        #expect(ws.undoActionName == "Undo Invert")
        let p = try plain.pixel(x: 0, y: 0), q = try ws.composite().pixel(x: 0, y: 0)
        #expect(abs(q.r - (1 - p.r)) < 0.01 && abs(q.g - (1 - p.g)) < 0.01)
        try Self.run("adjust.black-and-white", ["weights": Self.weights], on: &ws)
        #expect(ws.adjustments.kinds == [.invert, .blackAndWhite(.neutral)])
        let grey = try ws.composite().pixel(x: 1, y: 1)
        #expect(abs(grey.r - grey.g) < 0.01 && abs(grey.g - grey.b) < 0.01)
        ws.undo()
        ws.undo()
        #expect(ws.adjustments.kinds.isEmpty)
        #expect(try ws.composite() == plain)
    }

    @Test func blackAndWhiteAndInvertAreKindsOfAnAdjustmentLayer() throws {
        var ws = try Self.checker()
        ws.services.adjustmentLayers = LiveAdjustmentLayering()  // the fake brightens whatever the settings
        let plain = try ws.composite()
        ws.addAdjustmentLayer(.curves)
        // The kind commands act on the selected adjustment layer, not the image.
        try Self.run("adjust.invert", on: &ws)
        #expect(ws.kinds == [.invert] && ws.adjustments.kinds.isEmpty)
        #expect(ws.undoActionName == "Undo Invert")
        let p = try plain.pixel(x: 0, y: 0), q = try ws.composite().pixel(x: 0, y: 0)
        #expect(abs(q.r - (1 - p.r)) < 0.01)
        ws.undo()
        #expect(ws.kinds.isEmpty)
    }

    @Test func aLookAppliesAsOneStepAndSaves() throws {
        var ws = try Self.checker()
        try Self.run("look.apply", ["id": .string("bw-high-contrast")], on: &ws)
        let look = try #require(BuiltInLooks.look("bw-high-contrast"))
        #expect(ws.adjustments.kinds == look.kinds)
        #expect(ws.adjustments.tone == look.tone)
        #expect(ws.undoActionName == "Undo Apply Look")
        #expect(ws.currentLook.kinds == look.kinds && ws.currentLook.tone == look.tone)
        _ = try Self.catalog.run("look.save", params: .object(["name": .string("Mine")]), on: &ws)
        var other = PhotoWorkspace(services: ws.services)
        try other.open(rgba8: [10, 20, 30, 255], width: 1, height: 1, name: "dot.png")
        let mine = try #require(LookPreset.all(in: other.looks).first { $0.name == "Mine" })
        try Self.run("look.apply", ["id": .string(mine.id)], on: &other)
        #expect(other.adjustments.kinds == look.kinds && other.adjustments.tone == look.tone)
        other.undo()
        #expect(other.adjustments == AdjustmentSettings())
    }

    @Test func newAdjustmentLayerOffersBlackAndWhiteAndInvert() throws {
        var ws = try Self.checker()
        ws.services.adjustmentLayers = LiveAdjustmentLayering()  // the fake brightens whatever the settings
        let plain = try ws.composite()
        ws.addAdjustmentLayer(.invert)
        #expect(ws.selectedLayer?.name == "Invert 1" && ws.selectedLayer?.kind.label == "Invert adjustment layer")
        #expect(ws.kinds == [.invert])
        let p = try plain.pixel(x: 0, y: 0), q = try ws.composite().pixel(x: 0, y: 0)
        #expect(abs(q.r - (1 - p.r)) < 0.01)
        ws.addAdjustmentLayer(.blackAndWhite)
        #expect(ws.selectedLayer?.name == "Black & White 1" && ws.kinds == [.blackAndWhite(.neutral)])
    }

    @Test func theCatalogListsTheAdjustCommands() {
        let ids = Set(PhotoWorkspace.commands.map(\.id))
        for id in AdjustCommands.specs(PhotoWorkspace.self).map(\.id) { #expect(ids.contains(id), "\(id) is missing") }
    }

    @Test func kindsRoundTripAndAFileWithoutThemSavesAsBefore() throws {
        let plain = try JSONEncoder().encode(AdjustmentSettings())
        #expect(!String(decoding: plain, as: UTF8.self).contains("kinds"))
        var ws = try Self.checker()
        ws.services = .live  // PhotoHeadless opens through the live archive
        try Self.run("adjust.invert", on: &ws)
        ws.addAdjustmentLayer(.curves)
        try Self.run("adjust.black-and-white", ["weights": Self.weights], on: &ws)
        #expect(ws.kinds.count == 1)
        let saved = try PhotoHeadless(workspace: ws).save()
        let opened = try PhotoHeadless.open(saved, name: "kinds.ora")
        #expect(opened.workspace.adjustments.kinds == [.invert])
        #expect(opened.workspace.layers == ws.layers)
        #expect(try opened.save() == saved)
    }
}
