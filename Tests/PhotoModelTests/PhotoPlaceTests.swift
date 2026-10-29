// PhotoPlaceTests.swift (place-image PP-1 written, PP-5 turns on): MJ-PP, the Model walk of File > Place…
// in Photo. A placed PNG or JPEG becomes a pixel layer above the selection, fitted inside the canvas by the
// kernel's `PlaceRules.fitted` and centred or at the drop point, in one undo step; SVG is refused, the catalog's
// refusal naming only PNG and JPEG (#6027). The stub
// contract and the walk run now (PP-5 built PhotoPlace+Kernel's bodies). Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
@testable import PhotoModel
import SuiteKernel
import Testing

/// An 800 × 600 white image, its Background layer selected.
private func opened() throws -> PhotoWorkspace {
    var workspace = PhotoWorkspace()
    try workspace.newCanvas(width: 800, height: 600)
    return workspace
}

/// A `width` × `height` red PNG or JPEG as the asset Place hands the target.
private func asset(_ name: String, _ width: Int, _ height: Int, format: PlacedFormat = .png) throws -> PlacedAsset {
    let buffer = try PixelBuffer(width: width, height: height, fill: RGBA(r: 1, g: 0, b: 0, a: 1))
    let data = format == .jpeg ? try JPEG.write(buffer) : try PNG.write(buffer)
    return PlacedAsset(id: PlaceRules.assetID(of: data), name: name, format: format,
                       natural: Size(width: Double(width), height: Double(height)), data: data)
}

/// Places `asset` the way `place.image` does: fitted inside the canvas, centred or at `at`.
@discardableResult
private func place(_ asset: PlacedAsset, on workspace: inout PhotoWorkspace, at: Point? = nil) throws -> String {
    let box = PlaceRules.fitted(natural: asset.natural, in: workspace.placeCanvas, at: at)
    return try workspace.insertPlaced(asset, PlacedImage(assetID: asset.id, box: box), name: "Place Image")
}

@Suite struct PhotoPlaceTests {
    // The stub contract: what PP-5 keeps.

    @Test func takesPNGAndJPEGAndKeepsNoPicture() throws {
        let workspace = try opened()
        #expect(workspace.placeFormats == [.png, .jpeg])
        #expect(workspace.placeFillBox == nil)
        #expect(workspace.placedSelection == nil)
    }

    @Test func fitsInsideTheCanvas() throws {
        #expect(try opened().placeCanvas == Rect(minX: 0, minY: 0, maxX: 800, maxY: 600))
        #expect(PhotoWorkspace().placeCanvas == Rect(minX: 0, minY: 0, maxX: 0, maxY: 0))
    }

    @Test func noImageSaysWhy() {
        #expect(PhotoWorkspace().placeHelp == "Open or make an image to place into.")
    }

    @Test func aPictureCantBeChanged() throws {
        var workspace = try opened()
        let image = PlacedImage(assetID: "a", box: Rect(minX: 0, minY: 0, maxX: 10, maxY: 10))
        #expect(throws: (any Error).self) { try workspace.setPlaced(image, asset: nil, name: "Replace Image", drag: nil) }
        #expect(workspace.layers.count == 1)
    }

    // MJ-PP: the place walk.

    @Test func centredOnCanvas() throws {
        var workspace = try opened()
        let id = try place(try asset("logo.png", 200, 100), on: &workspace)
        let layer = try #require(workspace.layers.first { $0.id == id })
        #expect(layer.name == "logo")
        #expect((layer.offsetX, layer.offsetY) == (300, 250))
        #expect(workspace.selectedLayerID == id)
        #expect(workspace.placeHelp == nil)
    }

    @Test func aboveSelection() throws {
        var workspace = try opened()
        let background = try #require(workspace.selectedLayerID)
        let id = try place(try asset("logo.png", 200, 100), on: &workspace)
        #expect(workspace.layers.map(\.id) == [id, background])
    }

    @Test func largeFitsCanvas() throws {
        var workspace = try opened()
        let id = try place(try asset("photo-4000x3000.jpg", 4000, 3000, format: .jpeg), on: &workspace)
        let tiles = try #require(workspace.pixels[id])
        #expect((tiles.width, tiles.height) == (800, 600))
        #expect(workspace.statusMessage == "Placed at 20%.")
    }

    @Test func dropNearTheEdgeStaysInside() throws {
        var workspace = try opened()
        let id = try place(try asset("logo.png", 200, 100), on: &workspace, at: Point(x: 790, y: 590))
        let layer = try #require(workspace.layers.first { $0.id == id })
        #expect((layer.offsetX, layer.offsetY) == (600, 500))
    }

    @Test func oneUndoStep() throws {
        var workspace = try opened()
        try place(try asset("logo.png", 200, 100), on: &workspace)
        workspace.undo()
        #expect(workspace.layers.map(\.name) == ["Background"])
    }

    @Test(arguments: [
        ("logo.svg", #"<svg xmlns="http://www.w3.org/2000/svg" width="240" height="80"/>"#),
        ("notes.txt", "not an image"),
    ])
    func svgAndTextRefused(_ name: String, _ text: String) throws {
        var workspace = try opened()
        let params = PlaceIntent.place(name: name, data: Data(text.utf8), at: nil).command.params
        let refusal = CatalogError.unavailable(id: "place.image", why: "Place takes PNG or JPEG files.")
        #expect(throws: refusal) { try PhotoWorkspace.catalog.run("place.image", params: params, on: &workspace) }
        #expect(workspace.layers.count == 1)
    }

    @Test func svgRefusalNamesPhotosFormats() throws {
        var workspace = try opened()
        workspace.place([(name: "logo.svg", data: Data(#"<svg xmlns="http://www.w3.org/2000/svg" width="240" height="80"/>"#.utf8))], at: nil)
        #expect(workspace.statusMessage == "Photo places PNG or JPEG files.")
        #expect(workspace.layers.count == 1)
    }

    @Test func placesThroughPhotosCatalog() throws {
        var workspace = try opened()
        let png = try asset("logo.png", 200, 100)
        workspace.place([(name: png.name, data: png.data)], at: nil)
        #expect(workspace.layers.map(\.name) == ["logo", "Background"])
        #expect(PhotoWorkspace.catalog.spec("place.image") != nil)
    }

    @Test func smallKeepsItsPixelsAndClearsTheNote() throws {
        var workspace = try opened()
        let id = try place(try asset("logo.png", 200, 100), on: &workspace)
        let tiles = try #require(workspace.pixels[id])
        #expect((tiles.width, tiles.height) == (200, 100))
        #expect(workspace.statusMessage == nil)
    }

    /// PP-5 moves Paste's insert into a shared helper; Paste keeps 100% and the view centre.
    @Test func pasteKeepsItsRule() throws {
        var workspace = try opened()
        let image = ClipboardImage(image: DecodedImage(rgba8: [UInt8](repeating: 255, count: 200 * 100 * 4), width: 200, height: 100),
                                   source: nil)
        workspace.paste(image, viewCenter: Mask.Point(x: 400, y: 300))
        let layer = try #require(workspace.selectedLayer)
        #expect((layer.offsetX, layer.offsetY) == (300, 250))
        #expect(workspace.layers.count == 2)
    }
}
