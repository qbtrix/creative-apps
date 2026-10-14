// PhotoHealToolTests.swift: the Heal tool (#422) drives the clone stamp with
// the tone match: Option-click, or a first drag with no source, samples the
// source and paints nothing; a later drag lays the source's texture in the
// tone of where it lands, as one undo step "Heal". Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoHealToolTests {
    /// A white image whose left half (x < 32) is black, the Heal tool selected.
    private func halfDark() throws -> PhotoWorkspace {
        var workspace = try whiteImage()
        workspace.setToolOption(.color(red: 0, green: 0, blue: 0))
        stroke(&workspace, .marquee, from: point(0, 0), to: point(32, 64))
        workspace.fillSelection()
        workspace.deselect()
        workspace.selectTool(.heal)
        return workspace
    }

    private func layer(_ workspace: PhotoWorkspace) throws -> TiledPixels {
        try #require(workspace.selectedLayerID.flatMap { workspace.pixels[$0] })
    }

    @Test func aFirstDragWithNoSourceSamplesItAndPaintsNothing() throws {
        var workspace = try halfDark()
        let pixels = try layer(workspace), steps = workspace.historySteps.count
        workspace.drag(from: point(8, 32), to: point(8, 32))
        workspace.drag(from: point(8, 32), to: point(40, 32))
        workspace.endDrag()
        #expect(workspace.cloneSource?.point == point(8, 32))
        #expect(try layer(workspace) == pixels)
        #expect(workspace.historySteps.count == steps)
    }

    @Test func healingDarkOntoBrightEndsAtTheBrightTone() throws {
        var workspace = try halfDark()
        workspace.drag(from: point(8, 32), to: point(8, 32), sampling: true)
        workspace.endDrag()
        workspace.drag(from: point(44, 32), to: point(44, 32))
        workspace.drag(from: point(44, 32), to: point(48, 32))
        workspace.endDrag()
        // A plain clone would paint black here; heal keeps the white it lands on.
        let healed = try layer(workspace).pixel(x: 46, y: 32)
        #expect(abs(healed.r - 1) < 0.05 && abs(healed.g - 1) < 0.05 && abs(healed.b - 1) < 0.05)
    }

    /// A gray image with a black dot (size 20) at (16, 32) and the source
    /// sampled on it, the Heal tool selected.
    private func dottedGray() throws -> PhotoWorkspace {
        var workspace = try whiteImage()
        workspace.setToolOption(.color(red: 128, green: 128, blue: 128))
        workspace.selectAll()
        workspace.fillSelection()
        workspace.deselect()
        workspace.setToolOption(.color(red: 0, green: 0, blue: 0))
        stroke(&workspace, .brush, from: point(16, 32), to: point(16, 32))
        workspace.selectTool(.heal)
        workspace.drag(from: point(16, 32), to: point(16, 32), sampling: true)
        workspace.endDrag()
        return workspace
    }

    @Test func healKeepsTheSourceTextureAsOneUndoStep() throws {
        // The dot carries over, darker than the gray around it.
        var workspace = try dottedGray()
        let steps = workspace.historySteps.count
        workspace.drag(from: point(46, 32), to: point(46, 32))
        workspace.endDrag()
        let after = try layer(workspace)
        #expect(try after.pixel(x: 46, y: 32).r < after.pixel(x: 46, y: 22).r)
        #expect(workspace.historySteps.count == steps + 1)
        #expect(workspace.undoActionName == "Undo Heal")
    }

    @Test func undoRestoresTheLayerExactly() throws {
        var workspace = try dottedGray()
        let before = try layer(workspace)
        workspace.drag(from: point(44, 32), to: point(44, 32))
        workspace.drag(from: point(44, 32), to: point(56, 40))
        workspace.endDrag()
        #expect(try layer(workspace) != before)
        workspace.undo()
        #expect(try layer(workspace) == before)
    }
}
