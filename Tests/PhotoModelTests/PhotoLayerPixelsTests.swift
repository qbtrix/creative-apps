// PhotoLayerPixelsTests.swift: layers hold pixels and the canvas is their
// composite (#191). Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoLayerPixelsTests {
    @Test func halfOpaqueRedOverWhiteIsPink() throws {
        var workspace = try whiteImage(4, 4)
        addFilledLayer(&workspace, red: 255, green: 0, blue: 0)
        let red = try #require(workspace.selectedLayerID)
        workspace.setOpacity(red, percent: 50)
        #expect(try canvasPixel(workspace, 1, 1) == RGBA(r: 1, g: 0.5, b: 0.5, a: 1))
    }

    @Test func hidingALayerGivesTheBackgroundBitForBit() throws {
        var workspace = try whiteImage(4, 4)
        let background = try workspace.composite()
        addFilledLayer(&workspace, red: 255, green: 0, blue: 0)
        workspace.toggleVisibility(try #require(workspace.selectedLayerID))
        #expect(try workspace.composite() == background)
    }

    @Test func multiplyMatchesCoreRasterComposite() throws {
        var workspace = try whiteImage(4, 4)
        addFilledLayer(&workspace, red: 0, green: 128, blue: 255)
        let top = try #require(workspace.selectedLayerID)
        workspace.setBlendMode(top, .multiply)
        let bottom = try #require(workspace.pixels[workspace.layers[1].id]).flattened()
        let expected = try composite(
            try #require(workspace.pixels[top]).flattened(), onto: bottom, mode: .multiply, opacity: 1)
        #expect(try workspace.composite() == expected)
    }

    @Test func aNewLayerIsTransparentAndChangesNothing() throws {
        var workspace = try whiteImage(4, 4)
        let before = try workspace.composite()
        workspace.addLayer()
        #expect(try layerPixel(workspace, 2, 2) == RGBA.clear)
        #expect(try workspace.composite() == before)
    }

    @Test func deletingALayerTakesItsPixelsOffTheCanvas() throws {
        var workspace = try whiteImage(4, 4)
        let before = try workspace.composite()
        addFilledLayer(&workspace, red: 0, green: 0, blue: 0)
        #expect(try canvasPixel(workspace, 0, 0) != before.pixel(x: 0, y: 0))
        #expect(workspace.removeLayer(try #require(workspace.selectedLayerID)))
        #expect(try workspace.composite() == before)
        #expect(workspace.pixels.count == workspace.layers.count)
    }
}
