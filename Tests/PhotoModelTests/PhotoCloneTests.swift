// PhotoCloneTests.swift: the clone stamp copies pixels from a sampled source
// onto the selected layer as one undo step (#422, model slice). Runs on Linux
// and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoCloneTests {
    /// A white image with a red dab (size 20) at (16, 32) on its one layer.
    private func dabbedImage() throws -> PhotoWorkspace {
        var workspace = try whiteImage()
        workspace.setToolOption(.color(red: 255, green: 0, blue: 0))
        stroke(&workspace, .brush, from: point(16, 32), to: point(16, 32))
        return workspace
    }

    private func layer(_ workspace: PhotoWorkspace) throws -> TiledPixels {
        try #require(workspace.selectedLayerID.flatMap { workspace.pixels[$0] })
    }

    @Test func copiesTheSourcePixelsExactlyInsideTheDab() throws {
        var workspace = try dabbedImage()
        let before = try layer(workspace)
        workspace.setCloneSource(at: point(16, 32))
        workspace.clone(along: [point(40, 32)], size: 30)
        let after = try layer(workspace)
        // Radius 15 at full hardness: every pixel centered 14 or less from the dab is copied outright,
        // the red dab's antialiased edge included.
        for y in 18..<47 {
            for x in 26..<55 {
                let dx = Double(x) + 0.5 - 40, dy = Double(y) + 0.5 - 32
                guard dx * dx + dy * dy <= 14 * 14 else { continue }
                let (got, want) = (try after.pixel(x: x, y: y), try before.pixel(x: x - 24, y: y))
                #expect(got == want, "\(x),\(y) \(got) \(want)")
            }
        }
        #expect(try after.pixel(x: 60, y: 32) == before.pixel(x: 60, y: 32))
        #expect(workspace.undoActionName == "Undo Clone")
        #expect(workspace.cloneSource?.offset?.x == -24 && workspace.cloneSource?.offset?.y == 0)
    }

    @Test func undoRestoresTheLayerBitForBit() throws {
        var workspace = try dabbedImage()
        let before = try layer(workspace)
        let steps = workspace.historySteps.count
        workspace.setCloneSource(at: point(16, 32))
        workspace.clone(along: [point(40, 20), point(48, 44)], size: 24)
        #expect(workspace.historySteps.count == steps + 1)
        workspace.undo()
        #expect(try layer(workspace) == before)
        workspace.redo()
        #expect(try layer(workspace) != before)
    }

    @Test func withNoSourceNothingChanges() throws {
        var workspace = try dabbedImage()
        let before = workspace
        workspace.clone(along: [point(40, 32)], size: 30)
        #expect(workspace == before)
    }

    @Test func cloningPixelsOntoTheirTwinsRecordsNoStep() throws {
        var workspace = try whiteImage()
        workspace.setCloneSource(at: point(10, 10))
        workspace.clone(along: [point(40, 40)], size: 20)
        #expect(workspace.canUndo == false)
    }

    @Test func theOffsetStaysUntilTheSourceIsSampledAgain() throws {
        var workspace = try dabbedImage()
        workspace.setCloneSource(at: point(16, 32))
        workspace.clone(along: [point(40, 32)], size: 4)
        workspace.clone(along: [point(30, 10)], size: 4)
        #expect(workspace.cloneSource?.offset?.x == -24 && workspace.cloneSource?.offset?.y == 0)
        workspace.setCloneSource(at: point(20, 30))
        #expect(workspace.cloneSource?.point == point(20, 30) && workspace.cloneSource?.offset == nil)
        workspace.clone(along: [point(50, 40)], size: 4)
        #expect(workspace.cloneSource?.offset?.x == -30 && workspace.cloneSource?.offset?.y == -10)
    }

    @Test func aStrokeReadsTheLayerAsItWasBeforeIt() throws {
        var workspace = try dabbedImage()
        let before = try layer(workspace)
        // Source 4 px left of the start, painting rightward over its own path: no smear.
        workspace.setCloneSource(at: point(16, 32))
        workspace.clone(along: [point(20, 32), point(40, 32)], size: 6)
        let after = try layer(workspace)
        for x in 21..<40 { #expect(try after.pixel(x: x, y: 32) == before.pixel(x: x - 4, y: 32)) }
    }

    @Test func halfOpacityBlendsHalfway() throws {
        var workspace = try dabbedImage()
        workspace.setToolOption(.opacity(percent: 50))
        workspace.setCloneSource(at: point(16, 32))
        workspace.clone(along: [point(40, 32)], size: 6)
        let blended = try #require(try layerPixel(workspace, 40, 32))
        #expect(abs(blended.r - 1) < 1e-5 && abs(blended.g - 0.5) < 1e-5 && abs(blended.a - 1) < 1e-5)
    }

    @Test func aSourceOffTheCanvasOrNotFiniteIsIgnored() throws {
        var workspace = try dabbedImage()
        workspace.setCloneSource(at: point(-1, 4))
        workspace.setCloneSource(at: point(64, 4))
        workspace.setCloneSource(at: point(.nan, 4))
        #expect(workspace.cloneSource == nil)
        workspace.setCloneSource(at: point(16, 32))
        let before = workspace
        workspace.clone(along: [point(.infinity, 32)], size: 10)
        workspace.clone(along: [point(40, 32)], size: .nan)
        workspace.clone(along: [], size: 10)
        #expect(workspace == before)
    }

    @Test func sourcePixelsOffTheLayerLeaveTheDestinationAlone() throws {
        var workspace = try dabbedImage()
        let before = try layer(workspace)
        workspace.setCloneSource(at: point(2, 32))
        workspace.clone(along: [point(60, 32)], size: 20)
        let after = try layer(workspace)
        // Offset -58: destination x 48..<58 reads off the left edge and stays.
        #expect(try after.pixel(x: 52, y: 32) == before.pixel(x: 52, y: 32))
    }

    @Test func aNewImageForgetsTheSource() throws {
        var workspace = try dabbedImage()
        workspace.setCloneSource(at: point(16, 32))
        try workspace.newCanvas(width: 32, height: 32)
        #expect(workspace.cloneSource == nil)
    }
}
