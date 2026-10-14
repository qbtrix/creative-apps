// PhotoCloneToolTests.swift: the Clone tool on the rail (#647). Its canvas
// drags clone live from the sampled source with the brush's options and end as
// one "Clone" undo step; sampling waits while a clone drag is under way. Runs
// on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoCloneToolTests {
    /// A white image with a red dab (size 20) at (16, 32), the Clone tool
    /// selected at size 30 with its source sampled on the dab.
    private func readyToClone() throws -> PhotoWorkspace {
        var workspace = try whiteImage()
        workspace.setToolOption(.color(red: 255, green: 0, blue: 0))
        stroke(&workspace, .brush, from: point(16, 32), to: point(16, 32))
        workspace.selectTool(.clone)
        workspace.setToolOption(.size(30))
        workspace.setCloneSource(at: point(16, 32))
        return workspace
    }

    @Test func aDragClonesWhileItMovesAndEndsAsOneStep() throws {
        var workspace = try readyToClone()
        let steps = workspace.historySteps.count
        let white = try #require(try layerPixel(workspace, 40, 32))
        workspace.drag(from: point(40, 32), to: point(40, 32))
        // The paint shows before the pointer lifts.
        #expect(try layerPixel(workspace, 40, 32) == layerPixel(workspace, 16, 32))
        workspace.drag(from: point(40, 32), to: point(44, 32))
        workspace.endDrag()
        #expect(workspace.historySteps.count == steps + 1)
        #expect(workspace.undoActionName == "Undo Clone")
        #expect(try layerPixel(workspace, 44, 32) == layerPixel(workspace, 20, 32))
        workspace.undo()
        #expect(try layerPixel(workspace, 40, 32) == white)
    }

    @Test func aToolDragMatchesTheSameStrokeAtOnce() throws {
        var dragged = try readyToClone()
        dragged.drag(from: point(40, 30), to: point(40, 30))
        dragged.drag(from: point(40, 30), to: point(46, 36))
        dragged.endDrag()
        var direct = try readyToClone()
        direct.clone(along: [point(40, 30), point(40, 30), point(46, 36)], size: 30)
        #expect(dragged.pixels == direct.pixels)
        #expect(dragged.cloneSource == direct.cloneSource)
    }

    @Test func withNoSourceADragChangesNoPixel() throws {
        var workspace = try whiteImage()
        workspace.selectTool(.clone)
        let pixels = workspace.pixels
        workspace.drag(from: point(8, 8), to: point(40, 40))
        workspace.endDrag()
        #expect(workspace.pixels == pixels)
        #expect(workspace.canUndo == false)
    }

    @Test func samplingWaitsUntilTheCloneDragEnds() throws {
        var workspace = try readyToClone()
        workspace.drag(from: point(40, 32), to: point(40, 32))
        workspace.setCloneSource(at: point(5, 5))
        #expect(workspace.cloneSource?.point == point(16, 32))
        workspace.endDrag()
        workspace.setCloneSource(at: point(5, 5))
        #expect(workspace.cloneSource?.point == point(5, 5) && workspace.cloneSource?.offset == nil)
    }

    @Test func theCloneToolUsesTheBrushOptions() throws {
        var workspace = try whiteImage()
        workspace.selectTool(.clone)
        workspace.setToolOption(.size(55))
        #expect(workspace.toolOptions.size == 55)
        workspace.selectTool(.brush)
        #expect(workspace.toolOptions.size == 55)
    }
}
