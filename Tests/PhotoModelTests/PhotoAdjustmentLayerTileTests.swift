// PhotoAdjustmentLayerTileTests.swift: AL-2 of photo-adjustment-layers. An
// adjustment layer goes through PhotoLayerComposite with the live service, so
// a partial redraw with one in a 3-layer stack equals the full frame (PF-12);
// at the top it equals the whole-image adjustments with the same settings bit
// for bit, hidden or at 0 % it equals no layer (PF-8 part two); Flatten
// through LiveMerging renders as the stack did. Runs on Linux and macOS.
import CoreRaster
@testable import PhotoModel
import Testing

@Suite struct PhotoAdjustmentLayerTileTests {
    /// Adds a Curves layer (a strong S curve) above the selected layer through
    /// the workspace API and returns its id and settings.
    private func addCurves(_ workspace: inout PhotoWorkspace) throws -> (PhotoLayer.ID, AdjustmentSettings) {
        workspace.addAdjustmentLayer(.curves)
        let id = try #require(workspace.selectedLayerID)
        workspace.adjustLayer(id, .curvePoints([CurvePoint(x: 0, y: 0), CurvePoint(x: 0.25, y: 0.1),
                                                CurvePoint(x: 0.75, y: 0.9), CurvePoint(x: 1, y: 1)]))
        workspace.endAdjustLayer()
        let layer = try #require(workspace.layers.first { $0.id == id })
        guard case .adjustment(let settings) = layer.kind else {
            Issue.record("Curves 1 is not an adjustment layer")
            return (id, AdjustmentSettings())
        }
        #expect(settings != AdjustmentSettings())
        return (id, settings)
    }

    /// A 520 x 300 white Background (3 x 2 tiles, the last ones clipped) with
    /// a red block, on `PhotoWorkspace()` (.live).
    private func background() throws -> PhotoWorkspace {
        var workspace = try whiteImage(520, 300)
        workspace.setToolOption(.color(red: 200, green: 30, blue: 40))
        stroke(&workspace, .marquee, from: point(20, 30), to: point(300, 280))
        workspace.fillSelection()
        workspace.deselect()
        return workspace
    }

    /// The Background, the adjustment layer at 70 % Multiply above it, and a
    /// blue block screened at 60 % at the top: a 3-layer stack.
    private func stack() throws -> (PhotoWorkspace, adjustment: PhotoLayer.ID) {
        var workspace = try background()
        workspace.addLayer()
        workspace.setToolOption(.color(red: 20, green: 90, blue: 230))
        stroke(&workspace, .marquee, from: point(200, 100), to: point(500, 290))
        workspace.fillSelection()
        workspace.deselect()
        let top = try #require(workspace.selectedLayerID)
        workspace.setBlendMode(top, .screen)
        workspace.setOpacity(top, percent: 60)
        workspace.selectLayer(try #require(workspace.layers.last?.id))
        let (id, _) = try addCurves(&workspace)
        workspace.setOpacity(id, percent: 70)
        workspace.setBlendMode(id, .multiply)
        #expect(workspace.layers.count == 3)
        #expect(workspace.layers[0].id == top)
        #expect(workspace.layers[1].id == id)
        return (workspace, id)
    }

    @Test func tilesMatchFrame() async throws {
        var (workspace, id) = try stack()
        let frame = try await PhotoRenderer.render(workspace)
        // The adjustment shows: the stack without it renders differently.
        var without = workspace
        without.layers.removeAll { $0.id == id }
        #expect(try await PhotoRenderer.render(without).rgba8 != frame.rgba8)
        // Paint on the Background under the adjustment, then redraw only the
        // damaged tiles.
        let base = try #require(workspace.layers.last?.id)
        workspace.selectLayer(base)
        workspace.setToolOption(.color(red: 30, green: 200, blue: 90))
        stroke(&workspace, .marquee, from: point(240, 10), to: point(290, 60))
        workspace.fillSelection()
        workspace.deselect()
        let redrawn = try await PhotoRenderer.render(workspace, after: frame)
        let full = try await PhotoRenderer.render(workspace)
        #expect(redrawn.rgba8 == full.rgba8)
        #expect(redrawn.rgba8 != frame.rgba8)
    }

    @Test func anAdjustmentLayerAtTheTopEqualsWholeImageAdjustmentsBitForBit() async throws {
        var layered = try background()
        let (_, settings) = try addCurves(&layered)
        #expect(layered.layers.count == 2)
        var whole = try background()
        whole.adjustments = settings
        #expect(try layered.composite() == whole.composite())
        let a = try await PhotoRenderer.render(layered), b = try await PhotoRenderer.render(whole)
        #expect(a.rgba8 == b.rgba8)
    }

    @Test func aHiddenOrClearAdjustmentLayerEqualsNoLayer() async throws {
        let (workspace, id) = try stack()
        var without = workspace
        without.layers.removeAll { $0.id == id }
        let expected = try await PhotoRenderer.render(without).rgba8
        var hidden = workspace
        hidden.toggleVisibility(id)
        #expect(try await PhotoRenderer.render(hidden).rgba8 == expected)
        var clear = workspace
        clear.setOpacity(id, percent: 0)
        #expect(try await PhotoRenderer.render(clear).rgba8 == expected)
        // The per-layer step itself gives back the picture under a hidden one.
        let layer = try #require(hidden.layers.first { $0.id == id })
        let below = try TiledPixels(width: 300, height: 280, fill: RGBA(r: 0.2, g: 0.5, b: 0.7, a: 1))
        let result = try PhotoLayerComposite.composite(
            LayerContent(layer: layer, pixels: nil), onto: below, origin: (x: 0, y: 0),
            adjusting: LiveAdjustmentLayers.make(), masking: LiveSelection.masking())
        #expect(result == below)
    }

    @Test func flattenOfTheStackEqualsTheRender() async throws {
        var (before, _) = try stack()
        before.adjust(.exposure(-0.3))
        let canvas = try #require(before.canvas)
        let flat = try LiveMerging().flatten(
            before.layers.map { LayerContent(layer: $0, pixels: before.pixels[$0.id]) }, canvas: canvas,
            adjustments: before.adjustments)
        var after = before
        let background = try #require(before.layers.last)
        after.layers = [background]
        after.pixels = [background.id: flat]
        after.adjustments = AdjustmentSettings()
        #expect(try after.composite() == before.composite())
        let a = try await PhotoRenderer.render(after), b = try await PhotoRenderer.render(before)
        #expect(a.rgba8 == b.rgba8)
    }
}
