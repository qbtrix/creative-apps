// HaloTimelineHelpTests.swift: the timeline's tooltip names the ruler's unit
// and frame rate, the bar and the diamonds, and says why keys can't be picked
// yet; a key click selects its layer meanwhile. Runs on Linux and macOS.
@testable import HaloModel
import Testing

private func keyed() throws -> HaloProject {
    var project = HaloProject()
    project.restore(try #require(HaloFixtures.project("keyed")))
    return project
}

@Test func timelineHelpSaysTheRulerCountsFramesAndNamesTheBarAndKeys() throws {
    let project = try keyed()
    let comp = try #require(project.selectedComposition)
    #expect(comp.framesPerSecond == 24)
    let help = project.timelineHelp
    #expect(help.contains("frames") && help.contains("24 per second"))
    #expect(help.contains("in point to its out point") && help.contains("diamonds are its keys"))
    #expect(help.contains("Drag the ruler") && help.contains("I sets"))
}

@Test func timelineHelpGivesTheKeyPickingReasonAndAKeyClickSelectsTheLayer() throws {
    let project = try keyed()
    let pick = HaloCommand.selectLaneKeys(layerID: "comp-1-layer-2", frame: 12, extending: false)
    let reason = try #require(project.unavailableHelp(for: pick))
    #expect(project.timelineHelp.hasSuffix(reason))
    #expect(project.keyClickCommand(layerID: "comp-1-layer-2", frame: 12) == .selectLayer("comp-1-layer-2"))
}

@Test func timelineHelpWithoutACompositionStillNamesFrames() {
    #expect(HaloProject().timelineHelp.hasPrefix("The ruler counts frames."))
}
