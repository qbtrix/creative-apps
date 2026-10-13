// PhotoImageOpsTests.swift: the Image menu's Image Size and Rotate. Runs on
// Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoImageOpsTests {
    @Test func imageSizeResamplesEveryLayer() throws {
        var workspace = try whiteImage(40, 20)
        addFilledLayer(&workspace, red: 255, green: 0, blue: 0)
        try workspace.resizeImage(width: 20, height: 10)
        #expect(workspace.canvas == CanvasSize(width: 20, height: 10))
        #expect(workspace.layers.allSatisfy { workspace.pixels[$0.id]?.width == 20 })
        #expect(workspace.undoActionName == "Undo Image Size")
        workspace.undo()
        #expect(workspace.canvas == CanvasSize(width: 40, height: 20))
    }

    @Test func aBadSizeThrowsAndChangesNothing() throws {
        var workspace = try whiteImage(4, 4)
        let before = workspace
        #expect(throws: RasterError.self) { try workspace.resizeImage(width: 0, height: 4) }
        #expect(throws: RasterError.self) { try workspace.resizeImage(width: 4, height: PhotoWorkspace.maxSide + 1) }
        #expect(workspace == before)
    }

    @Test func aQuarterTurnSwapsTheSidesAndMovesPixels() throws {
        var workspace = try whiteImage(6, 4)
        workspace.addLayer()
        stroke(&workspace, .marquee, from: point(0, 0), to: point(1, 1))
        workspace.fillSelection()
        workspace.rotateImage(.degrees90)
        #expect(workspace.canvas == CanvasSize(width: 4, height: 6))
        // The top-left pixel turns to the top-right.
        #expect(try canvasPixel(workspace, 3, 0) == RGBA(r: 0, g: 0, b: 0, a: 1))
        workspace.rotateImage(.degrees270)
        #expect(try canvasPixel(workspace, 0, 0) == RGBA(r: 0, g: 0, b: 0, a: 1))
        workspace.undo()
        workspace.undo()
        #expect(workspace.canvas == CanvasSize(width: 6, height: 4))
    }

    @Test func aMovedLayerKeepsItsPlaceThroughAHalfTurn() throws {
        var workspace = try whiteImage(10, 10)
        workspace.addLayer()
        stroke(&workspace, .marquee, from: point(0, 0), to: point(2, 2))
        workspace.fillSelection()
        workspace.deselect()
        stroke(&workspace, .move, from: point(1, 1), to: point(4, 1))
        workspace.rotateImage(.degrees180)
        // Painted at (3...4, 0...1) before the turn; (5...6, 8...9) after it.
        #expect(try canvasPixel(workspace, 5, 8) == RGBA(r: 0, g: 0, b: 0, a: 1))
        #expect(try canvasPixel(workspace, 4, 8) == RGBA(r: 1, g: 1, b: 1, a: 1))
    }
}
