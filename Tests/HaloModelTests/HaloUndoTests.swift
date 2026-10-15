// HaloUndoTests.swift (HF-2, #208): Undo and Redo on the live services. A
// step brings back the whole document, selection included (#127); redo goes
// forward again; the titles name the step; selecting and scrubbing record
// nothing; the history keeps 100 steps; and undo marks a saved file edited.
// Runs on Linux and macOS.
import HaloModel
import Testing

private func live(_ name: String) throws -> HaloProject {
    HaloProject(services: .live, document: try #require(HaloFixtures.project(name)))
}

@Test func undoNewLayerOnEmpty() throws {
    var project = try live("empty")
    let start = project.document
    project.newLayer(.solid)
    #expect(project.selectedLayer?.name == "Solid 1")
    #expect(project.undoTitle == "Undo New Layer")
    project.undo()
    #expect(project.selectedComposition?.layers.isEmpty == true)
    #expect(project.selectedLayerID == nil)
    #expect(project.compositions == start.compositions)
    #expect(project.undoTitle == nil)
    #expect(project.redoTitle == "Redo New Layer")
}

@Test func undoDeleteCompositionRestoresSelectionExactly() throws {
    var project = try live("two-comps")
    project.selectComposition("comp-2")
    project.selectLayer("comp-2-layer-2")
    let before = project.document
    #expect(project.selectedComposition?.name == "Outro")
    #expect(project.selectedLayer?.name == "Ball")

    project.deleteComposition("comp-2")
    #expect(project.compositions.count == 1)
    #expect(project.undoTitle == "Undo Delete Composition")

    project.undo()
    #expect(project.document == before)
    #expect(project.compositions.map(\.name) == ["Intro", "Outro"])
    let outro = try #require(project.compositions.last)
    #expect(outro.layers.first?.name == "Ball")
    #expect(outro.layers.first?.tracks["x"]?.count == 2)
    #expect(project.selectedCompositionID == "comp-2")
    #expect(project.selectedLayerID == "comp-2-layer-2")
    #expect(project.redoTitle == "Redo Delete Composition")

    project.redo()
    #expect(project.compositions.map(\.name) == ["Intro"])
    #expect(project.selectedCompositionID == "comp-1")
    #expect(project.undoTitle == "Undo Delete Composition")
    #expect(project.redoTitle == nil)
}

@Test func selectingAndScrubbingRecordNoStep() throws {
    var project = try live("two-comps")
    project.newLayer(.solid)
    let steps = project.history.undo.count
    project.selectComposition("comp-2")
    project.selectLayer("comp-2-layer-1")
    project.scrub(to: 30)
    #expect(project.selectedComposition?.playheadFrame == 30)
    #expect(project.history.undo.count == steps)
    #expect(project.redoTitle == nil)
}

@Test func historyKeepsTheNewest100Steps() throws {
    var project = try live("empty")
    for _ in 0..<101 { project.newLayer(.solid) }
    #expect(project.history.undo.count == 100)
    for _ in 0..<100 { project.undo() }
    #expect(project.selectedComposition?.layers.count == 1)
    #expect(project.undoTitle == nil)
}

@Test func undoAndRedoAfterSaveMarkTheFileEdited() throws {
    var project = try live("empty")
    project.newLayer(.solid)
    project.didSave(name: "Spot", path: "/t/Spot.halo")
    #expect(project.saveStatus == "Saved")
    project.undo()
    #expect(project.file.unsaved)
    #expect(project.saveStatus == "Edited")
    project.didSave(name: "Spot", path: "/t/Spot.halo")
    project.redo()
    #expect(project.file.unsaved)
}

@Test func undoAndRedoWithNothingToStepChangeNothing() throws {
    var project = try live("empty")
    let start = project
    project.undo()
    project.redo()
    #expect(project == start)
}
