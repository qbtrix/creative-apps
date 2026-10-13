// PhotoStraightenTests.swift: Image > Straighten, turning every layer by a
// small angle with or without Crop to Fit, its one undo step, the angles it
// ignores, a stale result it refuses to commit, and the frame the sheet
// previews. Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoStraightenTests {
    @Test func cropToFitKeepsTheProportionsInsideTheOriginalAndEveryPixelOpaque() throws {
        var workspace = try whiteImage(64, 48)
        try workspace.straighten(degrees: 5, cropToFit: true)
        let canvas = try #require(workspace.canvas)
        #expect(canvas.width < 64 && canvas.height < 48)
        // 4:3 within one pixel.
        #expect(abs(canvas.width - CanvasSize(width: 64, height: 48).width(forHeight: canvas.height)) <= 1)
        let picture = try workspace.composite()
        for y in 0..<canvas.height {
            for x in 0..<canvas.width { #expect(try picture.pixel(x: x, y: y).a >= 0.999) }
        }
    }

    @Test func withoutCropTheCanvasGrowsToTheTurnedBoundsWithClearCorners() throws {
        var workspace = try whiteImage(64, 48)
        try workspace.straighten(degrees: 5, cropToFit: false)
        let turned = try PixelBuffer(width: 64, height: 48).rotated(degrees: 5, filter: .bilinear)
        #expect(workspace.canvas == CanvasSize(width: turned.width, height: turned.height))
        #expect(workspace.canvas == CanvasSize(width: 68, height: 54))
        #expect(try canvasPixel(workspace, 0, 0).a == 0)
        #expect(try canvasPixel(workspace, 67, 53).a == 0)
        #expect(try canvasPixel(workspace, 34, 27).a >= 0.999)
    }

    @Test func everyLayerTurns() throws {
        var workspace = try whiteImage(64, 48)
        addFilledLayer(&workspace, red: 255, green: 0, blue: 0)
        try workspace.straighten(degrees: -5, cropToFit: false)
        #expect(workspace.layers.count == 2)
        for layer in workspace.layers {
            let pixels = try #require(workspace.pixels[layer.id])
            #expect(pixels.width == 68 && pixels.height == 54)
            #expect(try pixels.pixel(x: 0, y: 0).a == 0)
            #expect(try pixels.pixel(x: 34, y: 27).a >= 0.999)
        }
    }

    @Test func aMovedLayerTurnsAboutTheCanvasCenter() throws {
        var workspace = try whiteImage(64, 48)
        workspace.addLayer()
        stroke(&workspace, .marquee, from: point(0, 0), to: point(8, 8))
        workspace.fillSelection()
        workspace.deselect()
        stroke(&workspace, .move, from: point(1, 1), to: point(21, 13))
        #expect(workspace.selectedLayer?.offsetX == 20 && workspace.selectedLayer?.offsetY == 12)
        let expected = try workspace.composite().rotated(degrees: 10, filter: .lanczos3)
        try workspace.straighten(degrees: 10, cropToFit: false)
        // The black square, at (20...27, 12...19) before the turn, lands near (29.5, 20.2).
        let pixel = try canvasPixel(workspace, 29, 20)
        #expect(pixel.r < 0.05)
        #expect(abs(pixel.r - (try expected.pixel(x: 29, y: 20).r)) < 0.02)
    }

    @Test func oneUndoStepPutsBackTheSizeAndPixelsExactly() throws {
        var workspace = try whiteImage(64, 48)
        addFilledLayer(&workspace, red: 0, green: 0, blue: 255)
        workspace.selectAll()
        let before = workspace
        try workspace.straighten(degrees: 5, cropToFit: true)
        #expect(workspace.undoActionName == "Undo Straighten")
        #expect(workspace.selection == nil && workspace.pendingCrop == nil)
        workspace.undo()
        #expect(workspace.canvas == before.canvas)
        #expect(workspace.layers == before.layers)
        #expect(workspace.pixels == before.pixels)
        #expect(workspace.undoActionName == before.undoActionName)
    }

    @Test func aResultWorkedOutBeforeAnotherEditIsIgnored() throws {
        var workspace = try whiteImage(64, 48)
        let early = try #require(try workspace.straightened(degrees: 5, cropToFit: true))
        workspace.addLayer()
        let before = workspace
        let earlyCommitted = workspace.commitStraighten(early)
        #expect(!earlyCommitted)
        #expect(workspace == before)

        // A rename moves no revision, so the layer list catches it.
        let renamed = try #require(try workspace.straightened(degrees: 5, cropToFit: true))
        workspace.renameLayer(try #require(workspace.selectedLayerID), to: "Sky")
        let renamedCommitted = workspace.commitStraighten(renamed)
        #expect(!renamedCommitted)
        #expect(workspace.canvas == CanvasSize(width: 64, height: 48))
        #expect(workspace.undoActionName == "Undo Rename Layer")

        let fresh = try #require(try workspace.straightened(degrees: 5, cropToFit: true))
        let freshCommitted = workspace.commitStraighten(fresh)
        #expect(freshCommitted)
        #expect(workspace.canvas == CanvasSize(width: 51, height: 38))
        #expect(workspace.undoActionName == "Undo Straighten")
    }

    @Test(arguments: [0, Double.nan, Double.infinity, 45.5, -60])
    func anAngleItIgnoresChangesAndRecordsNothing(degrees: Double) throws {
        var workspace = try whiteImage(64, 48)
        let before = workspace
        try workspace.straighten(degrees: degrees, cropToFit: true)
        #expect(workspace == before)
        #expect(!workspace.canUndo)
    }

    @Test func withNoImageNothingHappens() throws {
        var workspace = PhotoWorkspace()
        try workspace.straighten(degrees: 5, cropToFit: true)
        #expect(workspace.canvas == nil && !workspace.canUndo)
        #expect(workspace.straightenFrame(degrees: 5, cropToFit: true) == nil)
    }

    @Test(arguments: [0.1, -7.5, 33.3, 45, -45])
    func theFrameMatchesTheEngine(degrees: Double) throws {
        let workspace = try whiteImage(64, 48)
        let frame = try #require(workspace.straightenFrame(degrees: degrees, cropToFit: true))
        let turned = try PixelBuffer(width: 64, height: 48).rotated(degrees: degrees, filter: .bilinear)
        #expect(frame.turned == CanvasSize(width: turned.width, height: turned.height))
        let crop = try PixelBuffer.straightenCrop(width: 64, height: 48, degrees: degrees)
        #expect(frame.crop == PixelRect(x: crop.x, y: crop.y, width: crop.width, height: crop.height))
        #expect(frame.size == CanvasSize(width: crop.width, height: crop.height))
        let whole = try #require(workspace.straightenFrame(degrees: degrees, cropToFit: false))
        #expect(whole.size == frame.turned && whole.crop == PixelRect(x: 0, y: 0, width: turned.width, height: turned.height))
    }

    @Test func theCropSitsOverTheOldCanvasWhereThePreviewShadesIt() throws {
        let frame = try #require(try whiteImage(64, 48).straightenFrame(degrees: 5, cropToFit: true))
        #expect(frame.turned == CanvasSize(width: 68, height: 54))
        #expect(frame.crop == PixelRect(x: 8, y: 8, width: 51, height: 38))
        #expect(frame.cropOrigin.x == 6 && frame.cropOrigin.y == 5)
    }

    @Test func theFrameAtZeroIsTheCanvas() throws {
        let workspace = try whiteImage(64, 48)
        #expect(workspace.straightenFrame(degrees: 0, cropToFit: true)?.size == CanvasSize(width: 64, height: 48))
        #expect(workspace.straightenFrame(degrees: .nan, cropToFit: true) == nil)
        #expect(workspace.straightenFrame(degrees: 46, cropToFit: false) == nil)
    }
}
