// PhotoRendererTests.swift: display bytes for the canvas, redrawn only where
// the image changed. A frame rendered from an older one always equals a fresh
// full render. Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoRendererTests {
    @Test func aFrameIsTheCompositeInDisplayBytes() async throws {
        var workspace = try whiteImage(300, 270)
        addFilledLayer(&workspace, red: 10, green: 200, blue: 90)
        workspace.setOpacity(try #require(workspace.selectedLayerID), percent: 60)
        let frame = try await PhotoRenderer.render(workspace)
        #expect(frame.width == 300 && frame.height == 270)
        #expect(frame.rgba8 == (try workspace.composite().rgba8()))
        #expect(frame.revision == workspace.revision)
        #expect(frame.milliseconds >= 0)
    }

    @Test func aStrokeRedrawsOnlyItsTilesAndStillMatchesAFullRender() async throws {
        var workspace = try whiteImage(600, 520)
        let first = try await PhotoRenderer.render(workspace)
        let since = workspace.revision
        stroke(&workspace, .brush, from: point(20, 20), to: point(60, 40))
        guard case .region(let region) = workspace.damage(since: since) else {
            Issue.record("a stroke damages a region")
            return
        }
        #expect(region.maxX <= 80 && region.maxY <= 60)
        #expect(PhotoRenderer.tilesCount(of: workspace, since: since) == 1)
        let next = try await PhotoRenderer.render(workspace, after: first)
        #expect(next.rgba8 == (try await PhotoRenderer.render(workspace)).rgba8)
    }

    @Test func adjustmentsAndLayerChangesRedrawEverything() throws {
        var workspace = try whiteImage(8, 8)
        let since = workspace.revision
        workspace.adjust(.exposure(1))
        #expect(workspace.damage(since: since) == .all)
        #expect(workspace.damage(since: workspace.revision) == .none)
    }

    @Test func aRendererFarBehindRedrawsEverything() throws {
        var workspace = try whiteImage(8, 8)
        let since = workspace.revision
        for step in 0..<70 { workspace.setOpacity(try #require(workspace.selectedLayerID), percent: Double(step)) }
        #expect(workspace.damage(since: since) == .all)
    }

    @Test func blurredTilesMatchTheWholeImage() async throws {
        var workspace = try whiteImage(520, 300)
        workspace.addLayer()
        stroke(&workspace, .marquee, from: point(250, 0), to: point(262, 300))
        workspace.fillSelection()
        workspace.adjust(.blurSigma(4))
        let frame = try await PhotoRenderer.render(workspace)
        // The stripe crosses the tile edge at x 256: each tile reads its blur margin.
        #expect(frame.rgba8 == (try workspace.composite().rgba8()))
    }

    @Test func noImageMeansNoFrame() async {
        await #expect(throws: RasterError.self) { try await PhotoRenderer.render(PhotoWorkspace()) }
    }
}

extension PhotoRenderer {
    /// How many tiles a render after `since` redraws.
    static func tilesCount(of workspace: PhotoWorkspace, since: Int) -> Int {
        guard let canvas = workspace.canvas else { return 0 }
        return tiles(of: canvas, in: workspace.damage(since: since)).count
    }
}
