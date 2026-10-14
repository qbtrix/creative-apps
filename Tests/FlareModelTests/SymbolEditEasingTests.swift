// SymbolEditEasingTests.swift: while a symbol is edited in place, the easing editor reads the selected layer from
// the symbol's own timeline, not the scene's (#643). Easing writes still address scene layers in FlareCore, so
// inside a symbol they are refused with a message instead of reaching a scene layer.
import FlareCore
@testable import FlareModel
import Testing

private func editingWaveHand() -> FlareWorkspace {
    var w = FlareWorkspace(services: .fake())
    w.load(FlareFixtures.character)
    w.editSymbol("wave")
    w.selectLayer("hand")
    return w
}

@Test func theEasingEditorShowsTheSymbolLayersSegments() {
    var w = editingWaveHand()
    let frames = (w.editingSymbol?.layers.first?.tracks["rotation"] ?? []).map(\.frame).sorted()
    let expected = zip(frames, frames.dropFirst()).map {
        EasingSegment(property: "rotation", startFrame: $0, endFrame: $1)
    }
    #expect(!expected.isEmpty)
    #expect(w.easingSegments == expected)
    let first = expected[0]
    w.selectEasingSegment(first)
    #expect(w.selectedEasingSegment == first)
    let start = w.editingSymbol?.layers.first?.tracks["rotation"]?.first { $0.frame == first.startFrame }
    #expect(w.currentEasing == start?.easing)
    #expect(!w.easingCurveSamples(count: 4).isEmpty)
}

@Test func anEasingPresetInASymbolIsRefusedAndLeavesTheDocument() {
    var w = editingWaveHand()
    guard let segment = w.easingSegments.first else { Issue.record("no segment"); return }
    w.selectEasingSegment(segment)
    let before = w.document
    w.setEasingPreset(.easeIn)
    #expect(w.layerError == .refused(FlareWorkspace.easingInSymbolMessage))
    #expect(w.document == before)
}

@Test func leavingTheSymbolReadsTheScenesLayersAgain() {
    var w = editingWaveHand()
    w.exitSymbol()
    #expect(w.easingSegments.isEmpty)
}

// #668: inside a symbol the editor says why its easing controls can't act, so the view disables them.
@Test func insideASymbolTheEasingControlsCarryAReason() {
    var w = editingWaveHand()
    guard let segment = w.easingSegments.first else { Issue.record("no segment"); return }
    w.selectEasingSegment(segment)
    #expect(w.currentEasing != nil)
    #expect(w.easingUnavailableReason == FlareWorkspace.easingInSymbolMessage)
    w.exitSymbol()
    #expect(w.easingUnavailableReason == nil)
}

@Test func aSceneLayersEasingHasNoUnavailableReason() {
    var w = FlareWorkspace(services: .fake())
    w.load(FlareFixtures.character)
    #expect(w.easingUnavailableReason == nil)
    #expect(FakeEasingEditing().easingUnavailableReason == nil)
}

@Test func aFakeWithAReasonRefusesItsEdits() {
    var fake = FakeEasingEditing(unavailableReason: FlareWorkspace.easingInSymbolMessage)
    let before = fake.currentEasing
    fake.setEasingPreset(.hold)
    fake.moveEasingHandle(.first, to: Point(x: 0.4, y: 0.1))
    #expect(fake.currentEasing == before)
    #expect(!fake.canUndo)
    #expect(fake.easingUnavailableReason == FlareWorkspace.easingInSymbolMessage)
}
