// PhotoCloneToolTests.swift: the Clone tool on the rail drives the clone stamp
// through `drag` (#647): Option-click, or a first drag with no source, samples
// the source and paints nothing; a later drag clones at the brush's size as
// one undo step "Clone". Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoCloneToolTests {
    /// A white image with a red brush dab (size 20) at (16, 32), the Clone tool selected.
    private func dabbedImage() throws -> PhotoWorkspace {
        var workspace = try whiteImage()
        workspace.setToolOption(.color(red: 255, green: 0, blue: 0))
        stroke(&workspace, .brush, from: point(16, 32), to: point(16, 32))
        workspace.selectTool(.clone)
        return workspace
    }

    private func layer(_ workspace: PhotoWorkspace) throws -> TiledPixels {
        try #require(workspace.selectedLayerID.flatMap { workspace.pixels[$0] })
    }

    @Test func optionClickSamplesTheSourceAndPaintsNothing() throws {
        var workspace = try dabbedImage()
        let pixels = try layer(workspace), steps = workspace.historySteps.count
        workspace.drag(from: point(16, 32), to: point(16, 32), sampling: true)
        workspace.drag(from: point(16, 32), to: point(30, 32), sampling: true)
        workspace.endDrag()
        #expect(workspace.cloneSource?.point == point(16, 32))
        #expect(try layer(workspace) == pixels)
        #expect(workspace.historySteps.count == steps)
    }

    @Test func aFirstDragWithNoSourceSamplesItAndPaintsNothing() throws {
        var workspace = try dabbedImage()
        let pixels = try layer(workspace)
        workspace.drag(from: point(16, 32), to: point(16, 32))
        workspace.drag(from: point(16, 32), to: point(40, 32))
        workspace.endDrag()
        #expect(workspace.cloneSource?.point == point(16, 32))
        #expect(try layer(workspace) == pixels)
    }

    @Test func aDragAfterSamplingClonesAsOneUndoStep() throws {
        var workspace = try dabbedImage()
        workspace.setToolOption(.size(30))
        workspace.drag(from: point(16, 32), to: point(16, 32), sampling: true)
        workspace.endDrag()
        let before = try layer(workspace), steps = workspace.historySteps.count
        workspace.drag(from: point(40, 32), to: point(40, 32))
        workspace.drag(from: point(40, 32), to: point(44, 32))
        workspace.drag(from: point(40, 32), to: point(48, 32))
        workspace.endDrag()
        let after = try layer(workspace)
        // The red dab, copied 24 px right of where it was.
        #expect(try after.pixel(x: 40, y: 32) == before.pixel(x: 16, y: 32))
        #expect(try after.pixel(x: 40, y: 32) != before.pixel(x: 40, y: 32))
        #expect(workspace.historySteps.count == steps + 1)
        #expect(workspace.undoActionName == "Undo Clone")
        workspace.undo()
        #expect(try layer(workspace) == before)
    }

    @Test func theCursorFollowsTheBrushSize() throws {
        var workspace = try dabbedImage()
        workspace.setToolOption(.size(42))
        #expect(workspace.brushCursorDiameter == 42)
        #expect(PhotoTool.clone.isEnabled)
    }
}
