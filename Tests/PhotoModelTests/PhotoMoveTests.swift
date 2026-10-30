// PhotoMoveTests.swift: a Select drag pressed on the selected layer moves it
// (#197; Move folded into Select), and a move damages the canvas only where the
// layer was and is. Runs on Linux and macOS.
import CoreRaster
import Testing

@testable import PhotoModel

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
        stroke(&workspace, .select, from: point(10, 10), to: point(15, 13))
        let own = try #require(try layerPixel(workspace, 10, 10))
        #expect(try canvasPixel(workspace, 15, 13) == own)
        #expect(try canvasPixel(workspace, 9, 9) == RGBA(r: 1, g: 1, b: 1, a: 1))
        #expect(workspace.undoActionName == "Undo Move Layer")
    }

    @Test func movingBackRestoresTheCanvasBitForBit() throws {
        var workspace = try square()
        let before = try workspace.composite()
        stroke(&workspace, .select, from: point(10, 10), to: point(15, 13))
        stroke(&workspace, .select, from: point(15, 13), to: point(10, 10))
        #expect(try workspace.composite() == before)
    }

    @Test func undoPutsTheOffsetBack() throws {
        var workspace = try square()
        stroke(&workspace, .select, from: point(10, 10), to: point(15, 13))
        #expect(workspace.selectedLayer?.offsetX == 5 && workspace.selectedLayer?.offsetY == 3)
        workspace.undo()
        #expect(workspace.selectedLayer?.offsetX == 0 && workspace.selectedLayer?.offsetY == 0)
    }

    @Test func aMoveDamagesWhereTheLayerWasAndIs() throws {
        var workspace = try whiteImage(256, 160)
        let red = TiledPixels(try PixelBuffer(width: 16, height: 16, fill: RGBA(r: 1, g: 0, b: 0, a: 1)))
        let id = workspace.insertLayer(named: "Square", pixels: red, kind: .pixels, at: 0)
        let at = try #require(workspace.index(of: id))
        (workspace.layers[at].offsetX, workspace.layers[at].offsetY) = (8, 8)
        workspace.selectLayer(id)
        let start = workspace.revision
        stroke(&workspace, .select, from: point(10, 10), to: point(50, 30))
        // The square was at (8, 8) and is at (48, 28): the canvas changed in the box around both, nowhere else.
        #expect(workspace.damage(since: start) == .region(PixelRect(x: 8, y: 8, width: 56, height: 36)))
        #expect(workspace.selectedLayer?.offsetX == 48 && workspace.selectedLayer?.offsetY == 28)
    }

    @Test func aMoveAfterACropKeepsTheLayerAligned() throws {
        var workspace = try square()
        stroke(&workspace, .crop, from: point(4, 4), to: point(60, 60))
        workspace.applyCrop()
        // The square's corner was at canvas (8, 8); after the crop it is at (4, 4).
        #expect(try canvasPixel(workspace, 4, 4).g == 0)
        stroke(&workspace, .select, from: point(10, 10), to: point(12, 10))
        #expect(try canvasPixel(workspace, 6, 4).g == 0)
        #expect(try canvasPixel(workspace, 5, 4).g == 1)
    }
}
