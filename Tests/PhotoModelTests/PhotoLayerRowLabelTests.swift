// PhotoLayerRowLabelTests.swift: the words a Layers row carries (#1709,
// #1710): the kind symbol names the adjustment it holds whatever the layer is
// called, and the blend summary's tooltip says which value is the blend mode
// and which the opacity. Builds on `.fake`. Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoLayerRowLabelTests {
    /// An open 8 x 8 white image on `.fake`, one layer "Background".
    private func image() throws -> PhotoWorkspace {
        var workspace = PhotoWorkspace(services: .fake)
        try workspace.newCanvas(width: 8, height: 8)
        return workspace
    }

    @Test func renamedCurvesLayerStillReadsCurves() throws {
        var workspace = try image()
        workspace.addAdjustmentLayer(.curves)
        let curves = try #require(workspace.layers.first)
        workspace.renameLayer(curves.id, to: "Warm")
        let warm = try #require(workspace.layers.first { $0.id == curves.id })
        #expect(warm.name == "Warm")
        #expect(warm.kind.label == "Curves adjustment layer")
        let background = try #require(workspace.layers.last)
        #expect(background.kind.label == "Image layer")
    }

    @Test func eachOfferedKindIsNamed() throws {
        var workspace = try image()
        for kind in workspace.adjustmentLayerKinds {
            workspace.addAdjustmentLayer(kind)
            #expect(workspace.layers.first?.kind.label == "\(kind.title) adjustment layer")
        }
    }

    @Test func blendSummaryNamesModeAndOpacity() throws {
        var workspace = try image()
        let id = try #require(workspace.layers.first).id
        #expect(workspace.layerBlendSummary(id) == nil, "a Normal layer at 100% shows no summary")
        workspace.setBlendMode(id, .multiply)
        workspace.setOpacity(id, percent: 60)
        let summary = try #require(workspace.layerBlendSummary(id))
        #expect(summary.text == "Multiply 60%")
        #expect(summary.help == "Blend mode Multiply, opacity 60%")
        workspace.setBlendMode(id, .normal)
        #expect(workspace.layerBlendSummary(id)?.help == "Blend mode Normal, opacity 60%")
        workspace.setOpacity(id, percent: 100)
        #expect(workspace.layerBlendSummary(id) == nil)
        #expect(workspace.layerBlendSummary("missing") == nil, "an unknown id has no summary")
    }
}
