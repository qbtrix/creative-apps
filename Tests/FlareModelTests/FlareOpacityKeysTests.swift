// FlareOpacityKeysTests.swift (brush-keys BK-11, BK-12): Flare's digits set every selected layer's opacity through the
// kernel's BrushKeys rule and `layer.set-opacity`, one undo step; while recording they key opacity at the playhead.
import FlareCore
@testable import FlareModel
import SuiteKernel
import Testing

private func bounce(_ layers: [String] = ["ball"]) -> FlareWorkspace {
    var w = FlareWorkspace(services: .built)
    w.load(FlareFixtures.bounce)
    if layers.count > 1 { w.selectAll() } else if let id = layers.first { w.selectLayer(id) }
    return w
}

private func opacityKeys(_ id: String, _ w: FlareWorkspace) -> [Keyframe] {
    w.document?.layers(of: .scene("scene-1"))?.first { $0.id == id }?.tracks["opacity"] ?? []
}

private func opacity(_ w: FlareWorkspace) -> Double? { w.animatedProperties.first { $0.name == "opacity" }?.value }

/// The digit `key` as Flare's stage reads it: no brush tool, so a layer-opacity action.
private func digit(_ key: Character, _ w: FlareWorkspace) -> BrushKeyAction? {
    var digits = OpacityDigits()
    return BrushKeys.action(for: key, shift: false, settings: BrushSettings(), brushActive: w.activeBrush != nil,
                            digits: &digits, now: 0)
}

struct FlareOpacityKeysTests {
    @Test func digitThreeSetsTheBaseOpacityWithAutoKeyOff() throws {
        var w = bounce()
        w.setCurrentFrame(12)
        #expect(digit("3", w) == .layerOpacity(30))
        try w.setSelectedOpacity(30)
        #expect(opacityKeys("ball", w).allSatisfy { $0.frame != 12 })
        #expect(opacity(w) == 0.3)
        w.setCurrentFrame(40)
        #expect(opacity(w) == 0.3)
    }

    @Test func digitThreeKeysOpacityAtThePlayheadWhileRecording() throws {
        var w = bounce()
        w.setCurrentFrame(0)
        try w.setSelectedOpacity(80)
        w.toggleAutoKey()
        w.setCurrentFrame(12)
        try w.setSelectedOpacity(30)
        #expect(opacityKeys("ball", w).map(\.frame) == [0, 12])
        #expect(opacityKeys("ball", w).first { $0.frame == 12 }?.value == 0.3)
        #expect(opacity(w) == 0.3)
        w.setCurrentFrame(0)
        #expect(opacity(w) == 0.8)
    }

    @Test func opacitySetsEverySelectedLayerAsOneUndoStep() throws {
        var w = bounce(["ball", "shadow"])
        #expect(w.propertyLayerIDs.count == 2)
        let before = w.document
        try w.setSelectedOpacity(50)
        #expect(opacityKeys("ball", w).map(\.value) == [0.5])
        #expect(opacityKeys("shadow", w).map(\.value) == [0.5])
        w.undo()
        #expect(w.document == before)
    }

    @Test func setOpacityRunsFromTheCatalogAndSaysWhyNot() throws {
        var w = bounce()
        _ = try FlareWorkspace.catalog.run("layer.set-opacity", params: .object(["percent": .number(30)]), on: &w)
        #expect(opacity(w) == 0.3 && w.undoActionName == "Undo Layer Opacity")
        #expect(FlareWorkspace.catalog.availability("layer.set-opacity", on: w).why == nil)
        var none = FlareWorkspace(services: .built)
        #expect(FlareWorkspace.catalog.availability("layer.set-opacity", on: none).why == FlareLayerError.noDocument.message)
        none.load(FlareFixtures.bounce)
        #expect(none.layerOpacityHelp == "Select a layer first.")
        #expect(throws: CatalogError.self) { try none.setSelectedOpacity(30) }
    }

    @Test func theStageAndMenuSendOneScrubAtThePercent() {
        #expect(FlareWorkspace.opacityIntents(30)
            == [.inspector(.scrub(property: "opacity", value: 0.3, dragStart: 0.3)), .inspector(.endScrub)])
        #expect(FlareWorkspace.opacityMenuPercents == [10, 20, 30, 40, 50, 60, 70, 80, 90, 100])
        var w = bounce()
        w.toggleAutoKey()
        w.setCurrentFrame(12)
        for case .inspector(let intent) in FlareWorkspace.opacityIntents(30) {
            if case .scrub(let p, let v, let s) = intent { w.setProperty(p, to: v, dragStart: s) } else { w.endPropertyScrub() }
        }
        #expect(opacityKeys("ball", w).first { $0.frame == 12 }?.value == 0.3)
    }
}
