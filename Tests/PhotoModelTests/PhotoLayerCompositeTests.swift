// PhotoLayerCompositeTests.swift: the renderer composites each layer through
// PhotoLayerComposite (S-7b, review note 2 of photo-seams). The reference
// digests and probe pixels were taken from the renderer before it went through
// the hook, so the picture is the same bit for bit; an adjustment layer leaves
// the picture under it alone until photo-adjustment-layers fills that case;
// Image Size, Rotate and Straighten tell every layer's extras (PV-5's masks)
// about the change once per layer. Runs on Linux and macOS.
import CoreRaster
@testable import PhotoModel
import Testing

@Suite struct PhotoLayerCompositeTests {
    /// FNV-1a, 64-bit, over the bytes: a stable digest of a frame.
    private func digest(_ bytes: [UInt8]) -> UInt64 {
        bytes.reduce(0xcbf2_9ce4_8422_2325 as UInt64) { ($0 ^ UInt64($1)) &* 0x0000_0100_0000_01b3 }
    }

    /// The straight RGBA bytes of `frame` at (x, y).
    private func probe(_ frame: PhotoFrame, _ x: Int, _ y: Int) -> [UInt8] {
        let at = (y * frame.width + x) * 4
        return Array(frame.rgba8[at..<(at + 4)])
    }

    /// `sample` under two pixel layers: a red block multiplied at 60%, and a
    /// blue block screened at 50%, moved so it hangs off the top-left edge.
    private func threeLayers() throws -> PhotoWorkspace {
        var workspace = try PhotoWorkspace.fixture(.sample)
        workspace.addLayer()
        workspace.setToolOption(.color(red: 200, green: 30, blue: 40))
        stroke(&workspace, .marquee, from: point(100, 100), to: point(300, 250))
        workspace.fillSelection()
        workspace.deselect()
        let red = try #require(workspace.selectedLayerID)
        workspace.setBlendMode(red, .multiply)
        workspace.setOpacity(red, percent: 60)
        workspace.addLayer()
        workspace.setToolOption(.color(red: 20, green: 90, blue: 230))
        stroke(&workspace, .marquee, from: point(40, 30), to: point(520, 400))
        workspace.fillSelection()
        workspace.deselect()
        let blue = try #require(workspace.selectedLayerID)
        workspace.setBlendMode(blue, .screen)
        workspace.setOpacity(blue, percent: 50)
        stroke(&workspace, .move, from: point(300, 300), to: point(237, 271))
        return workspace
    }

    /// An open image with a pixel layer, an adjustment layer and another
    /// pixel layer, small enough to straighten quickly.
    private func smallStack() throws -> PhotoWorkspace {
        var workspace = try whiteImage(40, 30)
        addFilledLayer(&workspace, red: 10, green: 200, blue: 90)
        _ = workspace.insertLayer(named: "Curves 1", pixels: nil, kind: .adjustment(AdjustmentSettings()), at: 0)
        #expect(workspace.layers.count == 3)
        return workspace
    }

    @Test func theSampleRendersAsBeforeBitForBit() async throws {
        let frame = try await PhotoRenderer.render(try PhotoWorkspace.fixture(.sample))
        #expect(frame.width == 800 && frame.height == 600)
        #expect(digest(frame.rgba8) == 13_977_072_148_139_007_801)
        #expect(probe(frame, 0, 0) == [41, 107, 219, 255])
        #expect(probe(frame, 560, 220) == [255, 219, 77, 255])
        #expect(probe(frame, 799, 599) == [250, 158, 107, 255])
    }

    @Test func aThreeLayerStackRendersAsBeforeBitForBit() async throws {
        let workspace = try threeLayers()
        #expect(workspace.layers.count == 3)
        let frame = try await PhotoRenderer.render(workspace)
        #expect(digest(frame.rgba8) == 13_332_991_827_187_591_330)
        #expect(probe(frame, 150, 150) == [82, 99, 192, 255])
        #expect(probe(frame, 10, 10) == [47, 122, 233, 255])
        #expect(probe(frame, 200, 120) == [74, 97, 193, 255])
        #expect(probe(frame, 600, 500) == [215, 150, 126, 255])
        // A partial redraw after the stack changed still matches a full one.
        var moved = workspace
        stroke(&moved, .move, from: point(200, 200), to: point(203, 198))
        let redrawn = try await PhotoRenderer.render(moved, after: frame)
        let full = try await PhotoRenderer.render(moved)
        #expect(redrawn.rgba8 == full.rgba8)
    }

    @Test func aPixelLayerCompositesAtItsOffsetWithItsBlendAndOpacity() throws {
        let workspace = try threeLayers()
        let top = try #require(workspace.selectedLayer)
        let pixels = try #require(workspace.pixels[top.id])
        let below = try PixelBuffer(width: 64, height: 48, fill: RGBA(r: 0.4, g: 0.3, b: 0.2, a: 1))
        let result = try PhotoLayerComposite.composite(
            LayerContent(layer: top, pixels: pixels), onto: below, origin: (x: 10, y: 20),
            adjusting: workspace.services.adjustmentLayers, masking: workspace.services.masking)
        let whole = try pixels.flattened()
        let expected = try CoreRaster.composite(
            whole, onto: below, x: top.offsetX - 10, y: top.offsetY - 20, mode: top.blendMode,
            opacity: Float(top.opacity))
        #expect(result == expected)
    }

    @Test func anAdjustmentLayerLeavesThePictureBelowUnchanged() throws {
        let workspace = try PhotoWorkspace.fixture(.layered)
        let curves = try #require(workspace.layers.first { $0.name == "Curves 1" })
        let below = try PixelBuffer(width: 32, height: 16, fill: RGBA(r: 0.2, g: 0.5, b: 0.7, a: 1))
        // The fake adjustment service brightens by a stop, so a call would show.
        let result = try PhotoLayerComposite.composite(
            LayerContent(layer: curves, pixels: nil), onto: below, origin: (x: 0, y: 0),
            adjusting: workspace.services.adjustmentLayers, masking: workspace.services.masking)
        #expect(result == below)
    }

    @Test func imageSizeTellsEveryLayerOnce() throws {
        var workspace = try smallStack()
        let count = workspace.geometryChangeCount
        try workspace.resizeImage(width: 20, height: 15)
        #expect(workspace.geometryChangeCount == count + 3)
        #expect(workspace.lastGeometryChange?.change == .resized(scaleX: 0.5, scaleY: 0.5))
    }

    @Test func rotateTellsEveryLayerOnce() throws {
        var workspace = try smallStack()
        let count = workspace.geometryChangeCount
        workspace.rotateImage(.degrees90)
        #expect(workspace.geometryChangeCount == count + 3)
        #expect(workspace.lastGeometryChange?.change == .rotated(.degrees90))
    }

    @Test func straightenTellsEveryLayerOnce() throws {
        var workspace = try smallStack()
        let crop = try #require(workspace.straightenFrame(degrees: 5, cropToFit: true)).crop
        let count = workspace.geometryChangeCount
        try workspace.straighten(degrees: 5, cropToFit: true)
        #expect(workspace.geometryChangeCount == count + 3)
        #expect(workspace.lastGeometryChange?.change == .straightened(degrees: 5, crop: crop))
    }

    @Test func aStaleStraightenTellsNoLayer() throws {
        var workspace = try smallStack()
        let result = try #require(try workspace.straightened(degrees: 5, cropToFit: false))
        workspace.rotateImage(.degrees180)
        let count = workspace.geometryChangeCount
        let committed = workspace.commitStraighten(result)
        #expect(!committed)
        #expect(workspace.geometryChangeCount == count)
    }
}
