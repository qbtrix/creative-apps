// PhotoFixturesTests.swift: the fixtures of blueprint 4.4 (S-5): their size,
// their picture, their layer stack top first, and that each runs on the fake
// services with a clean history. Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoFixturesTests {
    /// The bottom layer's own pixel at (x, y).
    private func backgroundPixel(_ workspace: PhotoWorkspace, _ x: Int, _ y: Int) throws -> RGBA? {
        try workspace.layers.last.flatMap { workspace.pixels[$0.id] }?.pixel(x: x, y: y)
    }

    @Test func emptyHasNoImage() throws {
        let workspace = try PhotoWorkspace.fixture(.empty)
        #expect(workspace.canvas == nil)
        #expect(workspace.layers.isEmpty)
    }

    @Test func sampleIsTheTestPhoto() throws {
        let workspace = try PhotoWorkspace.fixture(.sample)
        #expect(workspace.canvas == CanvasSize(width: 800, height: 600))
        #expect(workspace.layers.map(\.name) == ["Background"])
        let sun = try #require(try backgroundPixel(workspace, 560, 220))
        #expect(sun.r > 0.8 && sun.g > 0.5 && sun.b < 0.2, "sun center is yellow: \(sun)")
        let sky = try #require(try backgroundPixel(workspace, 10, 10))
        #expect(sky.b > 0.5 && sky.b > sky.g && sky.b > sky.r, "(10, 10) is blue: \(sky)")
        let ground = try #require(try backgroundPixel(workspace, 10, 590))
        #expect(ground.r > ground.b, "the bottom is orange: \(ground)")
    }

    @Test func layeredStacksPaintOverCurvesOverBackground() throws {
        let workspace = try PhotoWorkspace.fixture(.layered)
        #expect(workspace.canvas == CanvasSize(width: 800, height: 600))
        #expect(workspace.layers.map(\.name) == ["Paint", "Curves 1", "Background"])
        let paint = try #require(workspace.layers.first)
        #expect(paint.kind == .pixels)
        #expect(paint.blendMode == .multiply)
        #expect(abs(paint.opacityPercent - 60) < 0.001)
        #expect(paint.hasMask && paint.isMaskEnabled)
        let mask = try #require(workspace.masks[paint.id])
        #expect(mask.width == 800 && mask.height == 600)
        #expect(workspace.pixels[paint.id] != nil)
        let curves = workspace.layers[1]
        guard case .adjustment(let settings) = curves.kind else {
            Issue.record("Curves 1 is \(curves.kind), not an adjustment layer")
            return
        }
        #expect(!settings.isIdentity(.curves))
        #expect(workspace.pixels[curves.id] == nil)
        #expect(!workspace.layers[2].hasMask && workspace.layers[2].kind == .pixels)
        #expect(workspace.selectedLayerID == paint.id)
        let stroke = try #require(workspace.pixels[paint.id]).pixel(x: 400, y: 410)
        #expect(stroke.a == 1 && stroke.r > 0.5 && stroke.g < 0.1, "the stroke is red: \(stroke)")
    }

    @Test func largeIsFourThousandByThreeThousandInThreeLayers() throws {
        let workspace = try PhotoWorkspace.fixture(.large)
        #expect(workspace.canvas == CanvasSize(width: 4000, height: 3000))
        #expect(workspace.layers.count == 3)
        for layer in workspace.layers {
            let tiles = try #require(workspace.pixels[layer.id])
            #expect(tiles.width == 4000 && tiles.height == 3000)
        }
        let top = try #require(workspace.layers.first.flatMap { workspace.pixels[$0.id] })
        #expect(try top.pixel(x: 0, y: 0) != top.pixel(x: 3999, y: 2999), "the noise varies")
        let bottom = try #require(try backgroundPixel(workspace, 0, 0))
        #expect(bottom != (try backgroundPixel(workspace, 3999, 2999)), "the gradient varies")
    }

    @Test(arguments: PhotoFixture.allCases)
    func everyFixtureRunsOnFakesWithACleanHistory(_ fixture: PhotoFixture) throws {
        let workspace = try PhotoWorkspace.fixture(fixture)
        #expect(workspace.services.archive is FakeArchive)
        #expect(workspace.services.adjustmentLayers is FakeAdjustmentLayers)
        #expect(workspace.toolHelp(.eyedropper) == nil)
        #expect(!workspace.canUndo)
        #expect(!workspace.isDirty)
        if fixture != .empty {
            #expect(workspace.selectedLayer != nil)
            #expect(Set(workspace.layers.map(\.id)).count == workspace.layers.count)
        }
    }
}
