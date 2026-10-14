// SceneLengthLabelTests.swift: when several frame labels sit past a shorter scene length, the refusal names the
// furthest one, so typing the frame it names is accepted (#632).
import FlareCore
@testable import FlareModel
import Testing

@Test func lengthRefusalNamesTheFurthestLabel() {
    var w = FlareWorkspace(services: .fake())
    w.load(FlareFixtures.button)
    w.setSceneTiming(fps: 24, durationFrames: 20)
    #expect(w.layerError?.message == "Length must reach frame 48, where the label \u{201C}pressed\u{201D} sits.")
    #expect(w.document == FlareFixtures.button && !w.canUndo)
    w.setSceneTiming(fps: 24, durationFrames: 48)
    #expect(w.selectedScene?.durationFrames == 48 && w.canUndo)
}

@Test(arguments: [["a": 48, "z": 24], ["a": 24, "z": 48], ["b": 48, "a": 48]])
func lengthRefusalDoesNotDependOnLabelNames(labels: [String: Int]) {
    var document = FlareFixtures.bounce
    guard !document.scenes.isEmpty else { return #expect(Bool(false)) }
    document.scenes[0].labels = labels
    var w = FlareWorkspace(services: .fake())
    w.load(document)
    w.setSceneTiming(fps: 24, durationFrames: 10)
    let name = labels.filter { $0.value == 48 }.keys.min() ?? ""
    #expect(w.layerError?.message == "Length must reach frame 48, where the label \u{201C}\(name)\u{201D} sits.")
}
