// PhotoEraserTests.swift: the eraser erases the selected layer to
// transparent (#193). Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoEraserTests {
    @Test func erasingLeavesTransparencyAlongTheDrag() throws {
        var workspace = try whiteImage()
        stroke(&workspace, .eraser, from: point(8, 8), to: point(40, 40))
        #expect(try canvasPixel(workspace, 24, 24) == RGBA.clear)
        #expect(try canvasPixel(workspace, 60, 4) == RGBA(r: 1, g: 1, b: 1, a: 1))
        #expect(workspace.undoActionName == "Undo Erase")
    }

    @Test func anAntialiasedEdgeKeepsItsColorWithPartAlpha() throws {
        var workspace = try whiteImage()
        stroke(&workspace, .eraser, from: point(32, 32), to: point(32, 32))
        // Radius 10 around (32, 32): pixel 41 has its center 9.5 out, half a pixel in from the edge.
        let edge = try canvasPixel(workspace, 41, 31).unpremultiplied()
        #expect(edge.a > 0 && edge.a < 1)
        #expect(abs(edge.r - 1) < 1e-4 && abs(edge.g - 1) < 1e-4)
    }

    @Test func undoRestoresTheLayerBitForBit() throws {
        var workspace = try whiteImage()
        let id = try #require(workspace.selectedLayerID)
        let before = try #require(workspace.pixels[id])
        stroke(&workspace, .eraser, from: point(8, 8), to: point(40, 40))
        workspace.undo()
        #expect(workspace.pixels[id] == before)
    }
}
