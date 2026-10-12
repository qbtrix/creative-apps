// HaloProjectTests.swift: behavior of HaloProject, the state behind Halo's
// window. Runs on Linux and macOS.
import HaloModel
import Testing

@Test func newCompositionIs1080p30AndSelected() {
    var project = HaloProject()
    #expect(project.selectedComposition == nil)
    project.newComposition()
    let comp = project.selectedComposition
    #expect(comp?.name == "Comp 1")
    #expect(comp?.width == 1920)
    #expect(comp?.height == 1080)
    #expect(comp?.framesPerSecond == 30)
    #expect(comp?.durationSeconds == 10)
}

@Test func durationIsZeroWithoutAFrameRate() {
    let comp = HaloComposition(id: "c", name: "C", width: 1, height: 1, framesPerSecond: 0, durationFrames: 30)
    #expect(comp.durationSeconds == 0)
}

@Test func compositionsNumberUpAndSelectionIgnoresUnknownIds() {
    var project = HaloProject()
    project.newComposition()
    project.newComposition()
    #expect(project.compositions.map(\.id) == ["comp-1", "comp-2"])
    project.selectComposition("comp-1")
    project.selectComposition("comp-9")
    #expect(project.selectedCompositionID == "comp-1")
}
