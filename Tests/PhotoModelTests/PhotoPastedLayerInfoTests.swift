// PhotoPastedLayerInfoTests.swift: after a paste the user can read where the
// new layer landed and how big it is (the inspector header names its size and
// origin when they differ from the canvas), and a Copy that takes nothing
// names the selected layer it read. Runs on Linux and macOS.
import CoreRaster
@testable import PhotoModel
import Testing

@Suite struct PhotoPastedLayerInfoTests {
    @Test func pastedLayerBoundsAreOnTheInfoLine() throws {
        var workspace = try whiteImage(800, 600)
        let bytes = [UInt8](repeating: 200, count: 200 * 100 * 4)
        workspace.paste(
            ClipboardImage(image: DecodedImage(rgba8: bytes, width: 200, height: 100), source: nil),
            viewCenter: point(400, 300))
        #expect(workspace.selectedLayer?.name == "Pasted Layer")
        #expect(workspace.inspectorHeaderDetails.contains("Pasted Layer 200 × 100 px at 300, 250"))
        #expect(workspace.inspectorHeaderDetails.first == "800 × 600 px")
    }

    @Test func aCanvasSizedLayerAddsNoBoundsLine() throws {
        var workspace = try whiteImage(32, 24)
        #expect(workspace.inspectorHeaderDetails == ["32 × 24 px", "sRGB · 1 layer"])
        workspace.addLayer()
        #expect(workspace.inspectorHeaderDetails == ["32 × 24 px", "sRGB · 2 layers"])
    }

    @Test func nothingToCopyNamesTheSelectedLayer() throws {
        var workspace = try whiteImage(32, 32)
        workspace.addLayer()
        let name = try #require(workspace.selectedLayer?.name)
        workspace.setSelection(PixelRect(x: 4, y: 4, width: 10, height: 10))
        #expect(workspace.copySelection() == nil)
        let message = try #require(workspace.statusMessage)
        #expect(message.hasPrefix("Nothing to copy."))
        #expect(message.contains("“\(name)”"))
        #expect(message.contains("selected area"))

        workspace.deselect()
        #expect(workspace.copySelection() == nil)
        #expect(workspace.statusMessage == "Nothing to copy. “\(name)” is empty.")
    }
}
