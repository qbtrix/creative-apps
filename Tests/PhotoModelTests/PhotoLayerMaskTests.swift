// PhotoLayerMaskTests.swift (masks-clipping PK-1, PK-5): a layer mask is grey coverage the
// layer's size and place. From Selection is white inside the marquee and black outside; a second mask is
// refused; Apply makes the hidden pixels transparent in one undo step; a crop cuts the mask with its layer;
// a duplicate copies it; Delete and Disable are one step each, Edit Mask none. PhotoMaskCommandTests checks
// the five commands' ids and reasons, and the clip flag every layer carries. Linux and macOS.
import CoreRaster
@testable import PhotoModel
import SuiteKernel
import Testing

/// A 16 x 12 image: the white Background under "Layer 1", filled opaque, moved 2 right and 1 down, selected.
func maskedFixture() throws -> (PhotoWorkspace, PhotoLayer.ID) {
    var ws = PhotoWorkspace(services: .fake)
    try ws.newCanvas(width: 16, height: 12)
    ws.addLayer(); ws.selectAll(); ws.fillSelection(); ws.deselect()
    ws.moveSelectedLayers(dx: 2, dy: 1)
    return (ws, try #require(ws.selectedLayerID))
}

/// Layer `id`'s mask grey at (`x`, `y`) in the layer's own pixels.
func maskGrey(_ ws: PhotoWorkspace, _ id: PhotoLayer.ID, _ x: Int, _ y: Int) -> Float? {
    try? ws.masks[id]?.flattened().pixel(x: x, y: y).r
}

@Suite struct PhotoLayerMaskTests {
    @Test func fromSelectionRevealsInside() throws {
        var (ws, id) = try maskedFixture()
        let marquee = PixelRect(x: 4, y: 3, width: 6, height: 5)
        ws.setSelection(marquee)
        try ws.addMask(.selection)
        let mask = try #require(ws.masks[id])
        #expect(mask.width == 16 && mask.height == 12)
        for y in 0..<12 {
            for x in 0..<16 {
                // The layer sits at (2, 1), so its pixel (x, y) is the canvas's (x + 2, y + 1).
                let inside = x + 2 >= marquee.x && x + 2 < marquee.maxX && y + 1 >= marquee.y && y + 1 < marquee.maxY
                #expect(maskGrey(ws, id, x, y) == (inside ? 1 : 0), "(\(x), \(y))")
            }
        }
        #expect(ws.selectedLayer?.hasMask == true)
        #expect(ws.historySteps.last == "Add Layer Mask")
        ws.undo()
        #expect(ws.masks[id] == nil && ws.selectedLayer?.hasMask == false)
    }

    @Test func revealAllIsRefusedWithAMask() throws {
        var (ws, id) = try maskedFixture()
        try ws.addMask(.hide)
        #expect(maskGrey(ws, id, 0, 0) == 0 && maskGrey(ws, id, 15, 11) == 0)
        let steps = ws.historySteps
        #expect(ws.addMaskHelp(.reveal) == "This layer already has a mask.")
        #expect(throws: PhotoRefusal("This layer already has a mask.")) { try ws.addMask(.reveal) }
        #expect(ws.historySteps == steps && maskGrey(ws, id, 0, 0) == 0)
        ws.undo()
        try ws.addMask(.reveal)
        #expect(maskGrey(ws, id, 0, 0) == 1 && maskGrey(ws, id, 15, 11) == 1)
    }

    @Test func applyIsOneStep() throws {
        var (ws, id) = try maskedFixture()
        ws.setSelection(PixelRect(x: 0, y: 0, width: 8, height: 12))
        try ws.addMask(.selection)
        let before = ws.pixels[id], mask = ws.masks[id], count = ws.historySteps.count
        try ws.applyMask()
        #expect(ws.historySteps.count == count + 1 && ws.historySteps.last == "Apply Layer Mask")
        #expect(ws.masks[id] == nil && ws.selectedLayer?.hasMask == false)
        let applied = try #require(ws.pixels[id]).flattened()
        // Canvas x < 8 is layer x < 6: kept opaque; the rest is hidden, so transparent.
        #expect(try applied.pixel(x: 5, y: 4).a == 1)
        #expect(try applied.pixel(x: 6, y: 4) == .clear)
        #expect(try applied.pixel(x: 15, y: 11) == .clear)
        ws.undo()
        #expect(ws.pixels[id] == before && ws.masks[id] == mask && ws.selectedLayer?.hasMask == true)
    }

    @Test func maskFollowsCrop() throws {
        var (ws, id) = try maskedFixture()
        let marquee = PixelRect(x: 4, y: 3, width: 6, height: 5)
        ws.setSelection(marquee)
        try ws.addMask(.selection)
        ws.pendingCrop = PixelRect(x: 3, y: 2, width: 8, height: 8)
        ws.applyCrop()
        let layer = try #require(ws.selectedLayer), mask = try #require(ws.masks[id])
        #expect(layer.offsetX == 0 && layer.offsetY == 0)
        #expect(mask.width == 8 && mask.height == 8)
        for y in 0..<8 {
            for x in 0..<8 {
                // The new canvas's (x, y) was the old canvas's (x + 3, y + 2).
                let inside = x + 3 >= marquee.x && x + 3 < marquee.maxX && y + 2 >= marquee.y && y + 2 < marquee.maxY
                #expect(maskGrey(ws, id, x, y) == (inside ? 1 : 0), "(\(x), \(y))")
            }
        }
    }

    @Test func maskKeepsItsLayersSize() throws {
        var (ws, id) = try maskedFixture()
        try ws.addMask(.reveal)
        func matches() -> Bool { ws.masks[id]?.width == ws.pixels[id]?.width && ws.masks[id]?.height == ws.pixels[id]?.height }
        ws.rotateImage(.degrees90)
        #expect(matches())
        try ws.resizeImage(width: 6, height: 8)
        #expect(matches())
        try ws.straighten(degrees: 5, cropToFit: false)
        #expect(matches())
        ws.selectLayerBelow()
        try ws.addMask(.reveal)
        let background = try #require(ws.selectedLayerID)
        try ws.resizeCanvas(width: 30, height: 30, anchor: .center)
        #expect(ws.masks[background]?.width == 30 && ws.masks[background]?.height == 30)
        #expect(matches())
    }

    @Test func duplicateCopiesTheMask() throws {
        var (ws, id) = try maskedFixture()
        ws.setSelection(PixelRect(x: 4, y: 3, width: 6, height: 5))
        try ws.addMask(.selection)
        ws.duplicateSelectedLayer()
        let copy = try #require(ws.selectedLayerID)
        #expect(copy != id && ws.selectedLayer?.hasMask == true)
        #expect(ws.masks[copy] == ws.masks[id])
    }

    @Test func deleteAndEnableAreOneStepEach() throws {
        var (ws, id) = try maskedFixture()
        try ws.addMask(.reveal)
        let count = ws.historySteps.count
        try ws.setMaskEnabled(false)
        #expect(ws.historySteps.count == count + 1 && ws.historySteps.last == "Disable Layer Mask")
        #expect(ws.selectedLayer?.isMaskEnabled == false && ws.masks[id] != nil)
        ws.undo()
        #expect(ws.selectedLayer?.isMaskEnabled == true)
        try ws.deleteMask()
        #expect(ws.historySteps.count == count + 1 && ws.historySteps.last == "Delete Layer Mask")
        #expect(ws.masks[id] == nil && ws.selectedLayer?.hasMask == false)
        ws.undo()
        #expect(ws.masks[id] != nil && ws.selectedLayer?.hasMask == true)
        ws.setEditsMask(true)
        #expect(ws.editsMask && ws.historySteps.count == count + 1 && ws.historyIndex == count - 1)
    }
}

@Suite struct PhotoMaskCommandTests {
    static let ids = ["layer.mask-add", "layer.mask-delete", "layer.mask-apply", "layer.mask-enable", "layer.mask-edit"]

    func why(_ id: String, _ ws: PhotoWorkspace) -> String? { PhotoWorkspace.catalog.availability(id, on: ws).why }

    @Test func theCatalogHasTheMaskCommands() {
        for id in Self.ids { #expect(PhotoWorkspace.catalog.spec(id) != nil, "\(id)") }
        #expect(PhotoWorkspace.catalog.spec("layer.mask-add")?.title == "Add Layer Mask")
        #expect(PhotoWorkspace.catalog.spec("layer.mask-delete")?.title == "Delete Layer Mask")
        #expect(PhotoWorkspace.catalog.spec("layer.mask-apply")?.title == "Apply Layer Mask")
    }

    @Test func eachCommandSaysWhyItIsOff() throws {
        for id in Self.ids { #expect(why(id, PhotoWorkspace(services: .fake)) == "Open an image first.", "\(id)") }
        var layered = try PhotoWorkspace.fixture(.layered)
        if let curves = layered.layers.first(where: { $0.name == "Curves 1" }) { layered.selectLayer(curves.id) }
        for id in Self.ids { #expect(why(id, layered) == "Select an image layer first.", "\(id)") }
        // "Paint" has a mask.
        let paint = try PhotoWorkspace.fixture(.layered)
        #expect(why("layer.mask-add", paint) == "This layer already has a mask.")
        for id in Self.ids.dropFirst() { #expect(why(id, paint) == nil, "\(id)") }
        let (plain, _) = try maskedFixture()
        #expect(why("layer.mask-add", plain) == nil)
        #expect(plain.addMaskHelp(.selection) == "Make a selection first.")
        for id in Self.ids.dropFirst() { #expect(why(id, plain) == "This layer has no mask.", "\(id)") }
    }

    @Test func aRefusalChangesNothing() throws {
        var (ws, _) = try maskedFixture()
        let before = ws
        #expect(throws: PhotoRefusal("Make a selection first.")) { try ws.addMask(.selection) }
        #expect(throws: PhotoRefusal("This layer has no mask.")) { try ws.deleteMask() }
        #expect(throws: PhotoRefusal("This layer has no mask.")) { try ws.applyMask() }
        #expect(throws: PhotoRefusal("This layer has no mask.")) { try ws.setMaskEnabled(false) }
        ws.setEditsMask(true)
        #expect(ws == before)
    }

    @Test func layersStartUnclipped() throws {
        var (ws, id) = try maskedFixture()
        #expect(ws.layers.allSatisfy { !$0.isClipped })
        // The flag rides along when the kernel reorders the layers.
        if let at = ws.index(of: id) { ws.layers[at].isClipped = true }
        ws.sendSelectedLayerBackward()
        #expect(ws.layers.first { $0.id == id }?.isClipped == true)
        // A document saved before the flag existed opens with every layer unclipped.
        let (saved, _) = try maskedFixture()
        let archive = LiveArchive(), package = try saved.documentPackage(archive: archive, codec: RawCodec())
        var reopened = PhotoWorkspace(services: .fake)
        try reopened.openDocument(package, name: "Old.ora", archive: archive, codec: RawCodec())
        #expect(reopened.layers.count == 2 && reopened.layers.allSatisfy { !$0.isClipped })
    }
}
