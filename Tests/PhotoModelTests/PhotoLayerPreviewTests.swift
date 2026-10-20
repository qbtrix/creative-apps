// PhotoLayerPreviewTests.swift (#3288): each pixel layer has a small preview
// for its Layers row, its longest side the size asked for and its shape the
// layer's; a committed edit changes it, a hidden layer still has one, and an
// adjustment layer has none (its row keeps the kind symbol). Linux-safe.
import CoreRaster
import Testing
@testable import PhotoModel

struct PhotoLayerPreviewTests {
    @Test func previewFollowsTheLayer() throws {
        var model = PhotoWorkspace()
        try model.newCanvas(width: 64, height: 32)
        let id = try #require(model.selectedLayerID)
        let white = try #require(model.layerPreview(id, longestSide: 24))
        #expect(white.width == 24 && white.height == 12 && white.rgba8.count == 24 * 12 * 4)
        #expect(white.rgba8.allSatisfy { $0 == 255 })
        model.selectAll()
        model.fillSelection()
        let filled = try #require(model.layerPreview(id, longestSide: 24))
        #expect(filled != white)
        model.toggleVisibility(id)
        #expect(model.layerPreview(id, longestSide: 24) == filled)
        #expect(model.layerPreview(id, longestSide: 0) == nil && model.layerPreview("nosuch", longestSide: 24) == nil)
    }

    @Test func anAdjustmentLayerHasNoPreview() throws {
        var model = PhotoWorkspace()
        try model.newCanvas(width: 16, height: 16)
        model.addAdjustmentLayer(.curves)
        let curves = try #require(model.selectedLayerID)
        #expect(model.layerPreview(curves, longestSide: 24) == nil)
        // A layer smaller than the preview keeps its own size.
        let background = try #require(model.layers.last?.id)
        let small = try #require(model.layerPreview(background, longestSide: 24))
        #expect(small.width == 16 && small.height == 16)
    }
}
