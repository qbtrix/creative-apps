// PhotoCloneToolTests.swift: the Clone tool on Photo's rail (#647). A drag
// with it clones from the sampled source at the brush's size, a segment per
// pointer move, and ends as one "Clone" undo step; with no source it changes
// no pixels. Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoCloneToolTests {
    /// A white image with a red dab (size 20) at (16, 32), the brush set to `size`, Clone selected.
    private func cloneReady(size: Double = 6) throws -> PhotoWorkspace {
        var workspace = try whiteImage()
        workspace.setToolOption(.color(red: 255, green: 0, blue: 0))
        stroke(&workspace, .brush, from: point(16, 32), to: point(16, 32))
        workspace.setToolOption(.size(size))
        workspace.selectTool(.clone)
        return workspace
    }

    private func layer(_ workspace: PhotoWorkspace) throws -> TiledPixels {
        try #require(workspace.selectedLayerID.flatMap { workspace.pixels[$0] })
    }

    /// Drags through `points` with the active tool, then lets go.
    private func drag(_ workspace: inout PhotoWorkspace, through points: [Mask.Point]) {
        guard let first = points.first else { return }
        var last = first
        for p in points {
            workspace.drag(from: last, to: p)
            last = p
        }
        workspace.endDrag()
    }

    @Test func aDragClonesFromTheSourceAsOneStep() throws {
        var workspace = try cloneReady()
        let before = try layer(workspace)
        let steps = workspace.historySteps.count
        workspace.setCloneSource(at: point(16, 32))
        // Source 4 px left of the start, painting rightward over its own path in three moves: no smear.
        drag(&workspace, through: [point(20, 32), point(27, 32), point(33, 32), point(40, 32)])
        let after = try layer(workspace)
        for x in 21..<40 { #expect(try after.pixel(x: x, y: 32) == before.pixel(x: x - 4, y: 32)) }
        #expect(workspace.historySteps.count == steps + 1)
        #expect(workspace.undoActionName == "Undo Clone")
        #expect(workspace.cloneSource?.offset?.x == -4 && workspace.cloneSource?.offset?.y == 0)
        workspace.undo()
        #expect(try layer(workspace) == before)
    }

    @Test func theDragUsesTheBrushSize() throws {
        var workspace = try cloneReady(size: 4)
        let before = try layer(workspace)
        workspace.setCloneSource(at: point(16, 32))
        drag(&workspace, through: [point(40, 32)])
        let after = try layer(workspace)
        // Radius 2: the dab's center is red, 4 px above it stays white.
        #expect(try after.pixel(x: 40, y: 32) == before.pixel(x: 16, y: 32))
        #expect(try after.pixel(x: 40, y: 28) == before.pixel(x: 40, y: 28))
        #expect(workspace.brushCursorDiameter == 4)
    }

    @Test func withNoSourceADragChangesNoPixels() throws {
        var workspace = try cloneReady()
        let before = try layer(workspace)
        let steps = workspace.historySteps.count
        drag(&workspace, through: [point(20, 32), point(40, 32)])
        #expect(try layer(workspace) == before)
        #expect(workspace.historySteps.count == steps)
    }

    @Test func switchingToolsEndsTheCloneStroke() throws {
        var workspace = try cloneReady()
        workspace.setCloneSource(at: point(16, 32))
        workspace.drag(from: point(40, 32), to: point(40, 32))
        workspace.selectTool(.move)
        #expect(workspace.undoActionName == "Undo Clone")
    }
}
