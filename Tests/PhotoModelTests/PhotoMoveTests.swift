// PhotoMoveTests.swift: the move tool moves the selected layer (#197). Runs
// on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoMoveTests {
    /// A white image with a top layer holding a red square at (8, 8)-(20, 20).
    private func square() throws -> PhotoWorkspace {
        var workspace = try whiteImage()
        workspace.addLayer()
        workspace.setToolOption(.color(red: 255, green: 0, blue: 0))
        stroke(&workspace, .marquee, from: point(8, 8), to: point(20, 20))
        workspace.fillSelection()
        workspace.deselect()
        return workspace
    }

    @Test func movingShiftsTheLayerOnTheCanvas() throws {
        var workspace = try square()
        stroke(&workspace, .move, from: point(30, 30), to: point(35, 33))
        let own = try #require(try layerPixel(workspace, 10, 10))
        #expect(try canvasPixel(workspace, 15, 13) == own)
        #expect(try canvasPixel(workspace, 9, 9) == RGBA(r: 1, g: 1, b: 1, a: 1))
        #expect(workspace.undoActionName == "Undo Move Layer")
    }

    @Test func movingBackRestoresTheCanvasBitForBit() throws {
        var workspace = try square()
        let before = try workspace.composite()
        stroke(&workspace, .move, from: point(30, 30), to: point(35, 33))
        stroke(&workspace, .move, from: point(35, 33), to: point(30, 30))
        #expect(try workspace.composite() == before)
    }

    @Test func undoPutsTheOffsetBack() throws {
        var workspace = try square()
        stroke(&workspace, .move, from: point(30, 30), to: point(35, 33))
        #expect(workspace.selectedLayer?.offsetX == 5 && workspace.selectedLayer?.offsetY == 3)
        workspace.undo()
        #expect(workspace.selectedLayer?.offsetX == 0 && workspace.selectedLayer?.offsetY == 0)
    }

    @Test func aMoveAfterACropKeepsTheLayerAligned() throws {
        var workspace = try square()
        stroke(&workspace, .crop, from: point(4, 4), to: point(60, 60))
        workspace.applyCrop()
        // The square's corner was at canvas (8, 8); after the crop it is at (4, 4).
        #expect(try canvasPixel(workspace, 4, 4).g == 0)
        stroke(&workspace, .move, from: point(10, 10), to: point(12, 10))
        #expect(try canvasPixel(workspace, 6, 4).g == 0)
        #expect(try canvasPixel(workspace, 5, 4).g == 1)
    }
}
