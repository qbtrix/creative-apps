// PhotoCropTests.swift: crop the image (#195). Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoCropTests {
    /// A 64x64 image whose Background has a different value at every pixel.
    private func gradient() throws -> PhotoWorkspace {
        var bytes: [UInt8] = []
        for y in 0..<64 { for x in 0..<64 { bytes += [UInt8(x * 4), UInt8(y * 4), 128, 255] } }
        var workspace = PhotoWorkspace()
        try workspace.open(rgba8: bytes, width: 64, height: 64, name: "g.png")
        return workspace
    }

    @Test func applyingACropCutsEveryLayerToIt() throws {
        var workspace = try gradient()
        addFilledLayer(&workspace, red: 255, green: 0, blue: 0)
        workspace.setOpacity(try #require(workspace.selectedLayerID), percent: 40)
        let old = try workspace.composite()
        let backgroundID = workspace.layers[1].id
        let oldBackground = try #require(workspace.pixels[backgroundID])
        stroke(&workspace, .crop, from: point(8, 8), to: point(40, 32))
        #expect(workspace.pendingCrop == PixelRect(x: 8, y: 8, width: 32, height: 24))
        workspace.applyCrop()
        #expect(workspace.canvas == CanvasSize(width: 32, height: 24))
        #expect(try workspace.pixels[backgroundID]?.pixel(x: 0, y: 0) == oldBackground.pixel(x: 8, y: 8))
        #expect(try canvasPixel(workspace, 0, 0) == old.pixel(x: 8, y: 8))
        #expect(workspace.pendingCrop == nil && workspace.undoActionName == "Undo Crop")
    }

    @Test func aClickCropsNothing() throws {
        var workspace = try gradient()
        stroke(&workspace, .crop, from: point(8, 8), to: point(8.5, 8.5))
        #expect(workspace.pendingCrop == nil)
        workspace.applyCrop()
        #expect(workspace.canvas == CanvasSize(width: 64, height: 64))
        #expect(!workspace.canUndo)
    }

    @Test func undoRestoresTheSizeAndPixelsBitForBit() throws {
        var workspace = try gradient()
        let before = try workspace.composite()
        stroke(&workspace, .crop, from: point(8, 8), to: point(40, 32))
        workspace.applyCrop()
        workspace.undo()
        #expect(workspace.canvas == CanvasSize(width: 64, height: 64))
        #expect(try workspace.composite() == before)
        workspace.redo()
        #expect(workspace.canvas == CanvasSize(width: 32, height: 24))
    }

    @Test func choosingAnotherToolDropsAPendingCrop() throws {
        var workspace = try gradient()
        stroke(&workspace, .crop, from: point(8, 8), to: point(40, 32))
        workspace.selectTool(.brush)
        #expect(workspace.pendingCrop == nil)
    }
}
