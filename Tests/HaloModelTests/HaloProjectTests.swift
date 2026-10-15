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

@Test func liveAndFakeProjectsStartEmpty() {
    for project in [HaloProject(), HaloProject(services: .fake)] {
        #expect(project.compositions.isEmpty)
        #expect(project.selectedCompositionID == nil && project.selectedLayerID == nil)
        #expect(project.document == HaloDocumentState())
        #expect(project.history == HaloHistory() && project.refusal == nil && project.renderedFrame == nil)
        #expect(project.playback == HaloPlaybackState() && project.playback.loops)
        #expect(project.file == HaloFileState() && project.selectedKeys.isEmpty && project.viewerDrag == nil)
    }
    #expect(HaloProject().services.drawing is LiveFrameDrawing)
    #expect(HaloProject(services: .fake).services.drawing is FakeFrameDrawing)
}

@Test func equalityComparesStateButNotServices() {
    // Services that record history alike but draw differently.
    var mixed = HaloServices.fake
    mixed.drawing = LiveFrameDrawing()
    var live = HaloProject(services: mixed), fake = HaloProject(services: .fake)
    #expect(live == fake)
    #expect(HaloProject() == HaloProject(services: .fake))
    live.newComposition()
    #expect(live != fake)
    fake.newComposition()
    #expect(live == fake)
    fake.newLayer(.solid)
    #expect(live != fake)
}

@Test func accessorsReadThroughTheDocument() {
    var project = HaloProject(services: .fake)
    project.newComposition()
    project.newComposition()
    project.newLayer(.text)
    #expect(project.compositions == project.document.compositions)
    #expect(project.selectedCompositionID == project.document.selectedCompositionID)
    #expect(project.selectedCompositionID == "comp-2")
    #expect(project.selectedLayerID == project.document.selectedLayerID && project.selectedLayerID != nil)
    #expect(project.document.nextCompositionNumber == 3)
    project.selectComposition("comp-1")
    #expect(project.document.selectedCompositionID == "comp-1" && project.document.selectedLayerID == nil)
}
