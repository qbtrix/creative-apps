// PhotoCanvasSizeTests.swift: Image > Canvas Size (transform PT-6). A larger
// size pads about the anchor with the background colour (white), a smaller
// one crops, every layer moves with the anchor, and the whole change is one
// "Canvas Size" undo step. RJ-P18 (Tests/RealJobs/photo/canvas-border/) runs
// here on PhotoHeadless, since the CLI's harness can't decode pixels yet.
// Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import SuiteKernel
import Testing

@Suite struct PhotoCanvasSizeTests {
    static let white = RGBA(r: 1, g: 1, b: 1, a: 1)

    /// A `width` x `height` image whose background is filled red, under a
    /// full-size layer painted black in its top-left 2 x 2 pixels.
    private func redUnderMarker(_ width: Int = 40, _ height: Int = 30) throws -> PhotoWorkspace {
        var workspace = try whiteImage(width, height)
        workspace.setToolOption(.color(red: 255, green: 0, blue: 0))
        workspace.selectAll()
        workspace.fillSelection()
        workspace.deselect()
        workspace.addLayer()
        stroke(&workspace, .marquee, from: point(0, 0), to: point(2, 2))
        workspace.setToolOption(.color(red: 0, green: 0, blue: 0))
        workspace.fillSelection()
        workspace.deselect()
        return workspace
    }

    /// The bottom (Background) layer's own pixel at (x, y).
    private func backgroundPixel(_ workspace: PhotoWorkspace, _ x: Int, _ y: Int) throws -> RGBA? {
        try workspace.layers.last.flatMap { workspace.pixels[$0.id] }?.pixel(x: x, y: y)
    }

    @Test func canvasSizeCentred() throws {
        var workspace = try redUnderMarker()
        let before = workspace.layers
        try workspace.resizeCanvas(width: 440, height: 430, anchor: .center)
        #expect(workspace.canvas == CanvasSize(width: 440, height: 430))
        // The marker layer moves by (200, 200); the background is padded to the canvas.
        for (old, new) in zip(before.dropLast(), workspace.layers.dropLast()) {
            #expect(new.offsetX == old.offsetX + 200 && new.offsetY == old.offsetY + 200, "\(new.name)")
        }
        #expect(try canvasPixel(workspace, 200, 200) == RGBA(r: 0, g: 0, b: 0, a: 1), "the marker sits at (200, 200)")
        #expect(try canvasPixel(workspace, 202, 202) == RGBA(r: 1, g: 0, b: 0, a: 1), "the red image follows it")
        #expect(try backgroundPixel(workspace, 239, 229) == RGBA(r: 1, g: 0, b: 0, a: 1))
        let background = try #require(workspace.layers.last)
        #expect(workspace.pixels[background.id].map { [$0.width, $0.height] } == [440, 430])
    }

    @Test func borderIsBackground() throws {
        var workspace = try redUnderMarker()
        try workspace.resizeCanvas(width: 440, height: 430, anchor: .center)
        // Every side of the 200 px band, not just the right and bottom, is opaque white.
        for (x, y) in [(0, 0), (439, 429), (199, 215), (240, 215), (220, 199), (220, 230), (0, 429), (439, 0)] {
            #expect(try backgroundPixel(workspace, x, y) == Self.white, "(\(x), \(y))")
            #expect(try canvasPixel(workspace, x, y) == Self.white, "(\(x), \(y))")
        }
        #expect(try backgroundPixel(workspace, 200, 200) == RGBA(r: 1, g: 0, b: 0, a: 1), "the image itself is untouched")
    }

    @Test func aTopLeftAnchorPadsOnlyTheRightAndBottom() throws {
        var workspace = try redUnderMarker()
        let before = workspace.layers
        try workspace.resizeCanvas(width: 50, height: 40, anchor: .topLeft)
        #expect(workspace.layers.map(\.offsetX) == before.map(\.offsetX))
        #expect(workspace.layers.map(\.offsetY) == before.map(\.offsetY))
        #expect(try canvasPixel(workspace, 0, 0) == RGBA(r: 0, g: 0, b: 0, a: 1))
        #expect(try backgroundPixel(workspace, 39, 29) == RGBA(r: 1, g: 0, b: 0, a: 1))
        #expect(try backgroundPixel(workspace, 45, 35) == Self.white)
    }

    @Test func aSmallerSizeCrops() throws {
        var workspace = try redUnderMarker()
        #expect(CanvasSizeDraft(old: CanvasSize(width: 40, height: 30)).with(width: 20).with(height: 10).cropNote
            == "The canvas will be cropped.")
        let before = workspace.layers
        try workspace.resizeCanvas(width: 20, height: 10, anchor: .center)
        #expect(workspace.canvas == CanvasSize(width: 20, height: 10))
        let background = try #require(workspace.layers.last)
        #expect(workspace.pixels[background.id].map { [$0.width, $0.height] } == [20, 10], "the background is cut to the canvas")
        #expect(try backgroundPixel(workspace, 0, 0) == RGBA(r: 1, g: 0, b: 0, a: 1))
        let marker = try #require(workspace.layers.first), old = try #require(before.first)
        #expect(marker.offsetX == old.offsetX - 10 && marker.offsetY == old.offsetY - 10)
    }

    @Test func oneUndoStep() throws {
        var workspace = try redUnderMarker()
        let steps = workspace.historySteps.count
        let layers = workspace.layers, pixels = workspace.pixels
        try workspace.resizeCanvas(width: 440, height: 430, anchor: .center)
        #expect(workspace.historySteps.count == steps + 1)
        #expect(workspace.historySteps.last == "Canvas Size")
        workspace.undo()
        #expect(workspace.canvas == CanvasSize(width: 40, height: 30))
        #expect(workspace.layers == layers)
        #expect(workspace.pixels == pixels)
    }

    @Test func aBadSizeOrTheSameSizeChangesNothing() throws {
        var workspace = try redUnderMarker()
        let before = workspace
        #expect(throws: RasterError.self) { try workspace.resizeCanvas(width: 0, height: 30, anchor: .center) }
        #expect(throws: RasterError.self) {
            try workspace.resizeCanvas(width: 40, height: PhotoWorkspace.maxSide + 1, anchor: .center)
        }
        try workspace.resizeCanvas(width: 40, height: 30, anchor: .bottomRight)
        #expect(workspace == before)
        var empty = PhotoWorkspace()
        #expect(throws: RasterError.self) { try empty.resizeCanvas(width: 4, height: 4, anchor: .center) }
    }

    @Test func theCatalogCommandRunsIt() throws {
        var workspace = try redUnderMarker()
        let params = JSONValue.object(["width": .number(48), "height": .number(30), "anchor": .string("right")])
        _ = try PhotoWorkspace.catalog.run("image.canvas-size", params: params, on: &workspace)
        #expect(workspace.canvas == CanvasSize(width: 48, height: 30))
        #expect(workspace.layers.first?.offsetX == 8)
        #expect(try backgroundPixel(workspace, 0, 0) == Self.white)
    }

    @Test func canvasBorderRealJob() throws {
        #expect(try PhotoJob.check("canvas-border") == [])
    }
}
