// PhotoBrushTests.swift: the brush paints on the selected layer, with undo
// (#192). Runs on Linux and macOS.
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

    @Test func dabsSitAQuarterOfTheSizeApart() {
        // Size 20: a dab every 5 px, so a 100 px segment adds 20 to the one at its start.
        let along = PhotoWorkspace.dabCenters(from: point(0, 0), to: point(100, 0), spacing: 5, walked: 0)
        #expect(along.centers.count + 1 == 21)
        #expect(along.centers.first == point(5, 0) && along.centers.last == point(100, 0))
        // The spacing carries across segments.
        let next = PhotoWorkspace.dabCenters(from: point(0, 0), to: point(7, 0), spacing: 5, walked: 3)
        #expect(next.centers == [point(2, 0), point(7, 0)])
        #expect(next.walked == 0)
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
}
