// PhotoAdjustmentLayerTests.swift: adjustment layers in the workspace (PV-6,
// AL-3): New Adjustment Layer's name, place, selection and one undo step; the
// inspector's adjust target, sections, header and info line; one gesture on a layer
// is one step and damages the canvas at once; ids never repeat; undo of a
// layer-list step with an adjustment layer. Builds on `.fake`
// (FakeAdjustmentLayers). Runs on Linux and macOS.
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoAdjustmentLayerTests {
    /// An open 8 x 8 white image on `.fake`, one layer "Background".
    private func image() throws -> PhotoWorkspace {
        var workspace = PhotoWorkspace(services: .fake)
        try workspace.newCanvas(width: 8, height: 8)
        return workspace
    }

    private func curve(_ y: Float) -> [CurvePoint] {
        [CurvePoint(x: 0, y: 0), CurvePoint(x: 0.5, y: y), CurvePoint(x: 1, y: 1)]
    }

    @Test func addGivesCurves1AboveTheSelectedLayerSelectedInOneStep() throws {
        var workspace = try image()
        workspace.addLayer()
        workspace.selectLayer(try #require(workspace.layers.last).id)
        let steps = workspace.historySteps.count
        workspace.addAdjustmentLayer(.curves)
        #expect(workspace.layers.map(\.name) == ["Layer 1", "Curves 1", "Background"])
        let added = workspace.layers[1]
        #expect(workspace.selectedLayerID == added.id)
        #expect(workspace.historySteps.count == steps + 1)
        #expect(workspace.undoActionName == "Undo New Adjustment Layer")
        #expect(workspace.pixels[added.id] == nil)
        guard case .adjustment(let settings) = added.kind else {
            Issue.record("not an adjustment layer")
            return
        }
        #expect(AdjustmentKind.allCases.filter { settings.isEnabled($0) } == [.curves])
        workspace.undo()
        #expect(workspace.layers.map(\.name) == ["Layer 1", "Background"])
    }

    @Test func namesCountPerKind() throws {
        var workspace = try image()
        workspace.addAdjustmentLayer(.curves)
        workspace.addAdjustmentLayer(.curves)
        workspace.addAdjustmentLayer(.levels)
        #expect(workspace.layers.map(\.name) == ["Levels 1", "Curves 2", "Curves 1", "Background"])
    }

    @Test func everyItemActsOrSaysWhy() throws {
        var empty = PhotoWorkspace(services: .fake)
        #expect(empty.addAdjustmentLayerHelp == "Open an image first.")
        empty.addAdjustmentLayer(.exposure)
        #expect(empty.layers.isEmpty)
        var workspace = try image()
        #expect(workspace.addAdjustmentLayerHelp == nil)
        #expect(workspace.adjustmentLayerKinds == [.exposure, .levels, .curves, .hueSaturation])
        for kind in workspace.adjustmentLayerKinds {
            let count = workspace.layers.count
            workspace.addAdjustmentLayer(kind)
            #expect(workspace.layers.count == count + 1)
            #expect(workspace.selectedLayer?.name == "\(kind.title) 1")
        }
        let count = workspace.layers.count
        workspace.addAdjustmentLayer(.blur)
        #expect(workspace.layers.count == count)
    }

    @Test func adjustTargetFollowsTheSelection() throws {
        var workspace = try image()
        let background = try #require(workspace.selectedLayerID)
        #expect(workspace.adjustTarget == .image)
        workspace.addAdjustmentLayer(.curves)
        let curves = try #require(workspace.selectedLayer)
        guard case .adjustment(let settings) = curves.kind else {
            Issue.record("not an adjustment layer")
            return
        }
        #expect(workspace.adjustTarget == .layer(curves.id, settings))
        workspace.selectLayer(background)
        #expect(workspace.adjustTarget == .image)
    }

    @Test func oneGestureOneStep() throws {
        var workspace = try image()
        workspace.addAdjustmentLayer(.curves)
        let id = try #require(workspace.selectedLayerID)
        let steps = workspace.historySteps.count
        for event in 1...30 { workspace.adjustLayer(id, .curvePoints(curve(0.5 + Float(event) / 100))) }
        workspace.endAdjustLayer()
        #expect(workspace.historySteps.count == steps + 1)
        #expect(workspace.undoActionName == "Undo Curves")
        guard case .layer(_, let dragged) = workspace.adjustTarget else {
            Issue.record("target lost")
            return
        }
        #expect(dragged.curvePoints == curve(0.5 + Float(30) / 100))
        workspace.adjustLayer(id, .curvePoints(curve(0.6)))
        #expect(workspace.historySteps.count == steps + 2)
        workspace.undo()
        workspace.undo()
        #expect(workspace.adjustTarget == .layer(id, Self.only(.curves)))
    }

    @Test func adjustDamagesAtOnce() throws {
        var workspace = try image()
        workspace.addAdjustmentLayer(.exposure)
        let id = try #require(workspace.selectedLayerID)
        let before = workspace.revision
        workspace.adjustLayer(id, .exposure(1))
        #expect(workspace.revision > before)
        #expect(workspace.damage(since: before) == .all)
    }

    @Test func adjustLayerKeepsTodaysRefusals() throws {
        var workspace = try image()
        workspace.addAdjustmentLayer(.levels)
        let id = try #require(workspace.selectedLayerID)
        let steps = workspace.historySteps.count
        workspace.adjustLayer(id, .blackPoint(1))
        workspace.adjustLayer(id, .exposure(2))
        workspace.adjustLayer(id, .setEnabled(.levels, false))
        workspace.adjustLayer(try #require(workspace.layers.last).id, .gamma(2))
        #expect(workspace.historySteps.count == steps)
        workspace.adjustLayer(id, .gamma(50))
        guard case .layer(_, let settings) = workspace.adjustTarget else {
            Issue.record("target lost")
            return
        }
        #expect(settings.gamma == AdjustmentSettings.gammaRange.upperBound)
        #expect(workspace.adjustments == AdjustmentSettings())
    }

    @Test func newIDIsNeverUsedBefore() throws {
        var workspace = try image()
        workspace.addLayer()
        let seen = Set(workspace.layers.map(\.id))
        workspace.removeLayer(try #require(workspace.selectedLayerID))
        workspace.addAdjustmentLayer(.hueSaturation)
        let id = try #require(workspace.selectedLayerID)
        #expect(!seen.contains(id))
        #expect(Set(workspace.layers.map(\.id)).count == workspace.layers.count)
    }

    @Test func undoOfALayerListStepWithAnAdjustmentLayerWorks() throws {
        var workspace = try image()
        workspace.addAdjustmentLayer(.curves)
        let id = try #require(workspace.selectedLayerID)
        workspace.toggleVisibility(id)
        #expect(workspace.selectedLayer?.isVisible == false)
        workspace.undo()
        #expect(workspace.selectedLayer?.isVisible == true)
        workspace.redo()
        #expect(workspace.selectedLayer?.isVisible == false)
    }

    @Test func layerInfoSaysNothingBelowAtTheBottomOnly() throws {
        var workspace = try image()
        let background = try #require(workspace.selectedLayerID)
        workspace.addAdjustmentLayer(.curves)
        let id = try #require(workspace.selectedLayerID)
        #expect(workspace.layerInfo(id) == nil)
        #expect(workspace.layerInfo(background) == nil)
        workspace.moveLayers(fromOffsets: [0], toOffset: workspace.layers.count)
        #expect(workspace.layers.last?.id == id)
        #expect(workspace.layerInfo(id) == "Nothing below to adjust.")
        #expect(workspace.layerInfo(background) == nil)
        #expect(workspace.layerInfo("missing") == nil)
    }

    @Test func sectionsAndHeaderFollowTheTarget() throws {
        var workspace = try image()
        let background = try #require(workspace.selectedLayerID)
        #expect(workspace.adjustSections == [.exposure, .levels, .curves, .blur, .hueSaturation])
        #expect(workspace.adjustHeader.title == "Image")
        #expect(workspace.adjustHeader.info == "Adjusts the whole image")
        workspace.addAdjustmentLayer(.curves)
        #expect(workspace.adjustSections == [.curves])
        #expect(workspace.adjustHeader.title == "Curves 1")
        #expect(workspace.adjustHeader.info == "Adjusts the layers below")
        workspace.selectLayer(background)
        #expect(workspace.adjustSections.count == 5)
        #expect(workspace.adjustHeader.title == "Image")
    }

    /// The `layered` fixture's "Curves 1" holds one kind, as a new layer does.
    @Test func layeredFixtureCurves1HoldsOnlyCurves() throws {
        var workspace = try PhotoWorkspace.fixture(.layered)
        let curves = try #require(workspace.layers.first { $0.name == "Curves 1" })
        workspace.selectLayer(curves.id)
        #expect(workspace.adjustSections == [.curves])
        #expect(workspace.adjustHeader.title == "Curves 1")
        guard case .adjustment(let settings) = curves.kind else {
            Issue.record("not an adjustment layer")
            return
        }
        #expect(AdjustmentKind.allCases.filter { settings.isEnabled($0) } == [.curves])
    }

    /// Default settings with only `kind` enabled.
    private static func only(_ kind: AdjustmentKind) -> AdjustmentSettings {
        var settings = AdjustmentSettings()
        for other in AdjustmentKind.allCases where other != kind { settings.apply(.setEnabled(other, false)) }
        return settings
    }
}
