// HaloTimelineHelpTests.swift: the timeline's tooltip names the ruler's unit
// and frame rate, the bar and the diamonds; once keys can be picked (EZ-5)
// a key click picks its lane's keys. Runs on Linux and macOS.
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

@Test func onceKeysCanBePickedAKeyClickPicksTheLaneAndTheHelpGivesNoReason() throws {
    let project = try keyed()
    let pick = HaloCommand.selectLaneKeys(layerID: "comp-1-layer-2", frame: 12, extending: false)
    #expect(project.unavailableHelp(for: pick) == nil)
    #expect(!project.timelineHelp.contains("picking keys:"))
    #expect(project.keyClickCommand(layerID: "comp-1-layer-2", frame: 12) == pick)
}

@Test func timelineHelpWithoutACompositionStillNamesFrames() {
    #expect(HaloProject().timelineHelp.hasPrefix("The ruler counts frames."))
}
