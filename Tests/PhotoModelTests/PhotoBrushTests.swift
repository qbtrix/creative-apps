// PhotoBrushTests.swift: the brush paints on the selected layer, with undo
// (#192); the brush and the eraser keep their own options (#26). Runs on
// Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoBrushTests {
    @Test func aStrokePaintsBlackAlongTheDragOnly() throws {
        var workspace = try whiteImage()
        stroke(&workspace, .brush, from: point(8, 8), to: point(40, 40))
        #expect(try canvasPixel(workspace, 24, 24) == RGBA(r: 0, g: 0, b: 0, a: 1))
        #expect(try canvasPixel(workspace, 60, 4) == RGBA(r: 1, g: 1, b: 1, a: 1))
        #expect(workspace.undoActionName == "Undo Paint")
    }

    @Test func aBigBrushLeavesAStraightEdgeNotScallops() throws {
        // Size 200 with samples 60 px apart: round dabs a quarter of the size
        // apart left a 3 px ripple along this edge.
        var workspace = try whiteImage(800, 400)
        workspace.setToolOption(.size(200))
        workspace.selectTool(.brush)
        for x in stride(from: 100.0, through: 700, by: 60) { workspace.drag(from: point(x, 200), to: point(x, 200)) }
        workspace.endDrag()
        for x in 150..<650 {
            // Row 101's centers sit 98.5 px from the stroke's middle, row 98's 101.5.
            #expect(try layerPixel(workspace, x, 101)?.r == 0 && layerPixel(workspace, x, 98)?.r == 1, "column \(x)")
        }
    }

    @Test func pressureScalesTheBrush() throws {
        var workspace = try whiteImage()
        workspace.selectTool(.brush)
        for (y, pressure) in [(16.0, 0.5), (48.0, 1)] {
            workspace.drag(from: point(8, y), to: point(56, y), pressure: pressure)
            workspace.endDrag()
        }
        // Size 20 at half pressure is 10 wide: 7 px off its line stays white; at full pressure it is painted.
        #expect(try layerPixel(workspace, 32, 23) == RGBA(r: 1, g: 1, b: 1, a: 1))
        #expect(try layerPixel(workspace, 32, 19)?.r == 0 && layerPixel(workspace, 32, 55)?.r == 0)
    }

    @Test func undoGivesTheLayerBackBitForBitAndRedoPaintsAgain() throws {
        var workspace = try whiteImage()
        let id = try #require(workspace.selectedLayerID)
        let before = try #require(workspace.pixels[id])
        stroke(&workspace, .brush, from: point(8, 8), to: point(40, 40))
        let painted = try #require(workspace.pixels[id])
        workspace.undo()
        #expect(workspace.pixels[id] == before)
        #expect(workspace.redoActionName == "Redo Paint")
        workspace.redo()
        #expect(workspace.pixels[id] == painted)
    }

    @Test func overlappingDabsNeverBuildPastTheStrokeOpacity() throws {
        var workspace = try whiteImage()
        workspace.setToolOption(.opacity(percent: 50))
        workspace.selectTool(.brush)
        workspace.drag(from: point(10, 32), to: point(10, 32))
        workspace.drag(from: point(10, 32), to: point(54, 32))
        workspace.drag(from: point(54, 32), to: point(10, 32))
        workspace.endDrag()
        let middle = try canvasPixel(workspace, 32, 32)
        #expect(abs(middle.r - 0.5) < 1e-5 && middle.a == 1)
    }

    @Test func colorSizeAndHardnessShapeTheDab() throws {
        var workspace = try whiteImage()
        workspace.setToolOption(.color(red: 255, green: 0, blue: 0))
        workspace.setToolOption(.size(8))
        workspace.setToolOption(.hardness(percent: 0))
        stroke(&workspace, .brush, from: point(32, 32), to: point(32, 32))
        let center = try canvasPixel(workspace, 31, 31), edge = try canvasPixel(workspace, 35, 31)
        #expect(center.r == 1 && center.g < 0.2)
        #expect(edge.g > center.g && edge.g < 1, "a soft dab fades toward its edge")
        #expect(try canvasPixel(workspace, 40, 31) == RGBA(r: 1, g: 1, b: 1, a: 1))
    }

    @Test func withNoImageADragChangesNothing() {
        var workspace = PhotoWorkspace()
        workspace.selectTool(.brush)
        let before = workspace
        workspace.drag(from: point(1, 1), to: point(9, 9))
        workspace.endDrag()
        #expect(workspace == before)
    }

    @Test func toolOptionsClamp() {
        var workspace = PhotoWorkspace()
        workspace.setToolOption(.size(9999))
        workspace.setToolOption(.opacity(percent: 0))
        workspace.setToolOption(.hardness(percent: .nan))
        #expect(workspace.toolOptions.size == 500)
        #expect(workspace.toolOptions.opacityPercent == 1)
        #expect(workspace.toolOptions.hardnessPercent == 100)
    }

    @Test func eachEraserOptionClamps() {
        var workspace = PhotoWorkspace()
        workspace.selectTool(.eraser)
        workspace.setToolOption(.size(0))
        workspace.setToolOption(.hardness(percent: -5))
        workspace.setToolOption(.opacity(percent: 250))
        #expect(workspace.eraserOptions.size == 1)
        #expect(workspace.eraserOptions.hardnessPercent == 0)
        #expect(workspace.eraserOptions.opacityPercent == 100)
        #expect(workspace.brushOptions == ToolOptions(), "the eraser's edits reached the brush")
    }

    @Test func brushAndEraserKeepTheirOwnOptions() {
        var workspace = PhotoWorkspace()
        workspace.selectTool(.brush)
        workspace.setToolOption(.size(40))
        workspace.setToolOption(.hardness(percent: 30))
        workspace.setToolOption(.opacity(percent: 60))
        workspace.selectTool(.eraser)
        #expect(workspace.toolOptions == ToolOptions(), "the eraser took the brush's options")
        workspace.setToolOption(.size(120))
        workspace.setToolOption(.opacity(percent: 25))
        workspace.selectTool(.brush)
        #expect(workspace.toolOptions.size == 40)
        #expect(workspace.toolOptions.hardnessPercent == 30)
        #expect(workspace.toolOptions.opacityPercent == 60)
        workspace.selectTool(.eraser)
        #expect(workspace.toolOptions.size == 120)
        #expect(workspace.toolOptions.hardnessPercent == 100)
        #expect(workspace.toolOptions.opacityPercent == 25)
    }

    @Test func aColorPickedWithTheEraserIsTheBrushColor() {
        var workspace = PhotoWorkspace()
        workspace.selectTool(.eraser)
        workspace.setToolOption(.color(red: 10, green: 20, blue: 30))
        workspace.selectTool(.brush)
        #expect(workspace.toolOptions.red == 10 && workspace.toolOptions.green == 20 && workspace.toolOptions.blue == 30)
    }

    @Test func theEraserPaintsWithItsOwnSize() throws {
        var workspace = try whiteImage()
        workspace.selectTool(.brush)
        workspace.setToolOption(.size(40))
        workspace.selectTool(.eraser)
        workspace.setToolOption(.size(4))
        stroke(&workspace, .eraser, from: point(32, 32), to: point(32, 32))
        #expect(try layerPixel(workspace, 32, 32)?.a == 0)
        // 8 px from the middle: inside a 40 px brush, outside the 4 px eraser.
        #expect(try layerPixel(workspace, 40, 32)?.a == 1)
    }

    @Test func theCursorDiameterInCanvasPixelsIsTheSize() throws {
        var workspace = try whiteImage()
        workspace.selectTool(.brush)
        workspace.setToolOption(.size(64))
        #expect(workspace.brushCursorDiameter == 64)
        workspace.selectTool(.eraser)
        workspace.setToolOption(.size(7))
        #expect(workspace.brushCursorDiameter == 7)
        workspace.selectTool(.marquee)
        #expect(workspace.brushCursorDiameter == nil)
        var empty = PhotoWorkspace()
        empty.selectTool(.brush)
        #expect(empty.brushCursorDiameter == nil, "no image, no cursor")
    }
}
