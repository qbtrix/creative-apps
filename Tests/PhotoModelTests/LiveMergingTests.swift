// LiveMergingTests.swift: PF-4 for the live Merge Down and Flatten (E-2 of
// photo-edit). The stack after a merge renders exactly as the stack before
// it, bit for bit, because both go through the renderer's per-layer step; an
// adjustment layer below refuses Merge Down; the merged layer covers both
// layers. Runs on Linux and macOS.
import CoreRaster
@testable import PhotoModel
import Testing

@Suite struct LiveMergingTests {
    /// A 96 x 80 white Background with a red block, and `upper` above it: a
    /// blue block on transparency, Screen at 60 %, moved by (7, 5) so it
    /// hangs off the canvas's right and bottom edges.
    private func twoLayers() throws -> PhotoWorkspace {
        var workspace = try whiteImage(96, 80)
        workspace.setToolOption(.color(red: 200, green: 30, blue: 40))
        stroke(&workspace, .marquee, from: point(10, 12), to: point(60, 50))
        workspace.fillSelection()
        workspace.deselect()
        workspace.addLayer()
        workspace.setToolOption(.color(red: 20, green: 90, blue: 230))
        stroke(&workspace, .marquee, from: point(30, 20), to: point(96, 80))
        workspace.fillSelection()
        workspace.deselect()
        let upper = try #require(workspace.selectedLayerID)
        workspace.setBlendMode(upper, .screen)
        workspace.setOpacity(upper, percent: 60)
        stroke(&workspace, .move, from: point(40, 40), to: point(47, 45))
        return workspace
    }

    private func content(_ workspace: PhotoWorkspace, _ layer: PhotoLayer) -> LayerContent {
        LayerContent(layer: layer, pixels: workspace.pixels[layer.id])
    }

    @Test func mergeDownRendersAsTheStackBeforeItBitForBit() async throws {
        let before = try twoLayers()
        let upper = before.layers[0], lower = before.layers[1]
        #expect(upper.offsetX == 7 && upper.offsetY == 5 && lower.name == "Background")
        let merged = try LiveEdit.merging().mergeDown(content(before, upper), onto: content(before, lower))
        var after = before
        after.layers = [lower]
        after.layers[0].offsetX = merged.x
        after.layers[0].offsetY = merged.y
        after.pixels = [lower.id: merged.pixels]
        #expect(try after.composite() == before.composite())
        let a = try await PhotoRenderer.render(after), b = try await PhotoRenderer.render(before)
        #expect(a.rgba8 == b.rgba8)
    }

    @Test func mergedBoundsCoverBothLayers() throws {
        let workspace = try twoLayers()
        let upper = workspace.layers[0], lower = workspace.layers[1]
        let merged = try LiveMerging().mergeDown(content(workspace, upper), onto: content(workspace, lower))
        #expect(merged.x == 0 && merged.y == 0)
        #expect(merged.pixels.width == 96 + 7 && merged.pixels.height == 80 + 5)
        // The part of upper off the canvas is kept, screened at 60 % on nothing.
        let corner = try merged.pixels.pixel(x: 100, y: 83)
        #expect(corner.a > 0.59 && corner.a < 0.61)
    }

    @Test func aHiddenUpperAddsNothing() throws {
        var workspace = try twoLayers()
        let upper = workspace.layers[0], lower = workspace.layers[1]
        workspace.toggleVisibility(upper.id)
        let merged = try LiveMerging().mergeDown(
            content(workspace, workspace.layers[0]), onto: content(workspace, lower))
        let background = try #require(workspace.pixels[lower.id])
        #expect(try merged.pixels.pixel(x: 40, y: 30) == background.pixel(x: 40, y: 30))
        #expect(try merged.pixels.pixel(x: 100, y: 83).a == 0)
    }

    @Test func anAdjustmentLowerRefuses() throws {
        let workspace = try twoLayers()
        var curves = PhotoLayer(id: "layer-99", name: "Curves 1")
        curves.kind = .adjustment(AdjustmentSettings())
        #expect(throws: PhotoRefusal("Merge Down needs a pixel layer below.")) {
            try LiveMerging().mergeDown(content(workspace, workspace.layers[0]), onto: LayerContent(layer: curves, pixels: nil))
        }
        #expect(LiveEdit.merging().unavailableHelp == nil)
    }

    @Test func flattenRendersAsTheStackBeforeItBitForBit() async throws {
        var before = try twoLayers()
        workspace3(&before)
        before.adjust(.exposure(0.7))
        #expect(before.layers.count == 3)
        let canvas = try #require(before.canvas)
        let flat = try LiveEdit.merging().flatten(
            before.layers.map { content(before, $0) }, canvas: canvas, adjustments: before.adjustments)
        #expect(flat.width == canvas.width && flat.height == canvas.height)
        var after = before
        let background = before.layers[2]
        after.layers = [background]
        after.pixels = [background.id: flat]
        after.adjustments = AdjustmentSettings()
        #expect(try after.composite() == before.composite())
        let a = try await PhotoRenderer.render(after), b = try await PhotoRenderer.render(before)
        #expect(a.rgba8 == b.rgba8)
    }

    @Test func flattenLeavesOutHiddenLayers() throws {
        var workspace = try twoLayers()
        workspace.toggleVisibility(workspace.layers[0].id)
        let canvas = try #require(workspace.canvas)
        let flat = try LiveMerging().flatten(
            workspace.layers.map { content(workspace, $0) }, canvas: canvas, adjustments: AdjustmentSettings())
        let background = try #require(workspace.pixels[workspace.layers[1].id])
        #expect(try flat.flattened() == background.flattened())
    }

    /// Adds a third layer: a green block multiplied at 70 %.
    private func workspace3(_ workspace: inout PhotoWorkspace) {
        workspace.addLayer()
        workspace.setToolOption(.color(red: 30, green: 200, blue: 90))
        stroke(&workspace, .marquee, from: point(5, 40), to: point(70, 75))
        workspace.fillSelection()
        workspace.deselect()
        if let top = workspace.selectedLayerID {
            workspace.setBlendMode(top, .multiply)
            workspace.setOpacity(top, percent: 70)
        }
    }
}
