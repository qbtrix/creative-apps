// HaloEditTests.swift: `edit`, the one place undo is recorded (QB-F3: one
// gesture, one step): each shipped mutator is one named step, a refusal
// changes nothing and shows under its control, a no-op is no step, scrubs
// coalesce, `restore` records nothing and layer ids are never reused. On
// `.fake`, whose history records. Runs on Linux and macOS.
import CoreRaster
@testable import HaloModel
import Testing

/// A project on `.fake` with one composition and one solid, selected.
func editProject() -> HaloProject {
    var project = HaloProject(services: .fake)
    project.newComposition()
    project.newLayer(.solid)
    return project
}

@Test func eachMutatorIsOneNamedStep() {
    var project = HaloProject(services: .fake)
    var names: [String] = []
    func step(_ name: String, _ change: (inout HaloProject) -> Void) {
        let before = project.history.undo.count
        change(&project)
        #expect(project.history.undo.count == before + 1, "\(name) recorded \(project.history.undo.count - before)")
        #expect(project.history.undoTitle == "Undo \(name)")
        names.append(name)
    }
    step("New Composition") { $0.newComposition() }
    step("Duplicate Composition") { $0.duplicateComposition("comp-1") }
    step("Rename Composition") { $0.renameComposition("comp-2", to: "Outro") }
    step("Delete Composition") { $0.deleteComposition("comp-2") }
    step("New Layer") { $0.newLayer(.solid) }
    step("Change Opacity") { $0.setSelectedLayerOpacity(0.5) }
    step("Change Blend Mode") { $0.setSelectedLayerBlendMode(.multiply) }
    #expect(project.history.undo.map(\.name) == names)
    #expect(project.selectedLayer?.opacity == 0.5 && project.selectedLayer?.blendMode == .multiply)
}

@Test func selectionAndScrubbingAreNotSteps() {
    var project = editProject()
    project.newComposition()
    let steps = project.history.undo.count
    project.selectComposition("comp-1")
    project.selectLayer(project.selectedComposition?.layers.first?.id ?? "")
    project.scrub(to: 40)
    #expect(project.history.undo.count == steps)
}

@Test func aThrowingBodySetsTheRefusalAndChangesNothing() {
    var project = editProject()
    let before = project
    let applied = project.edit("Break", control: "halo.test") { doc in
        doc.compositions = []
        throw HaloEditError.notANumber(.rotation)
    }
    #expect(!applied)
    #expect(project.refusal == HaloRefusal(control: "halo.test", message: "Rotation needs a number."))
    #expect(project.document == before.document && project.history == before.history)
    project.dismissRefusal()
    #expect(project.refusal == nil)
}

@Test func onlyARecordedEditMarksTheFileUnsaved() {
    var project = editProject()
    project.file.unsaved = false
    let steps = project.history.undo.count
    project.edit("Nothing", control: "halo.test") { _ in }
    #expect(project.history.undo.count == steps && !project.file.unsaved)
    project.setSelectedLayerOpacity(.nan)
    #expect(project.refusal?.control == "halo.inspector.row.opacity" && !project.file.unsaved)
    project.setSelectedLayerOpacity(0.25)
    #expect(project.history.undo.count == steps + 1 && project.file.unsaved && project.refusal == nil)
}

@Test func restoreRecordsNothingAndClearsTheRefusal() {
    var project = editProject()
    let steps = project.history.undo.count
    project.setSelectedLayerOpacity(.nan)
    project.restore(HaloDocumentState())
    #expect(project.compositions.isEmpty && project.refusal == nil && project.history.undo.count == steps)
}

@Test func scrubsWithOneKeyAreOneStepUntilCoalescingEnds() {
    var project = editProject()
    let steps = project.history.undo.count, before = project.document
    for x in [10.0, 20, 30] {
        project.edit("Change Position X", control: "halo.test", coalesceKey: "x") { doc in
            doc.compositions[0].layers[0].tracks["x"] = [HaloKeyframe(frame: 0, value: x)]
        }
    }
    #expect(project.history.undo.count == steps + 1 && project.history.undo.last?.before == before)
    project.endCoalescing()
    project.edit("Change Position X", control: "halo.test", coalesceKey: "x") { doc in
        doc.compositions[0].layers[0].tracks["x"] = [HaloKeyframe(frame: 0, value: 40)]
    }
    #expect(project.history.undo.count == steps + 2)
}

@Test func layerIDsAreNeverReusedAfterADelete() {
    var project = editProject()
    let first = project.selectedLayerID
    project.edit("Delete Layer", control: "halo.test") { doc in doc.compositions[0].layers.removeAll() }
    project.newLayer(.solid)
    #expect(project.selectedLayerID != first)
    let a = project.takeLayerID(in: "comp-1"), b = project.takeLayerID(in: "comp-1")
    #expect(a != b && a != first && a != project.selectedLayerID)
}

/// A rasterizer whose every line box is 250 × 90.
struct FixedBoxRasterizer: TextRasterizing {
    func measure(_ text: HaloTextContent) -> HaloLayerRect { HaloLayerRect(x: 0, y: 0, width: 250, height: 90) }
    func rasterize(_ text: HaloTextContent, color: HaloLayerColor) throws -> PixelBuffer {
        try PixelBuffer(width: 250, height: 90)
    }
}

@Test func newTextStoresTheMeasuredBoxOrTheEstimate() {
    var services = HaloServices.fake
    services.text = FixedBoxRasterizer()
    var project = HaloProject(services: services)
    project.newComposition()
    project.newLayer(.text)
    #expect(project.selectedLayer?.text.map { ($0.string, $0.width, $0.height) } ?? ("", 0, 0) == ("Text", 250, 90))
    var bare = HaloProject()
    bare.newComposition()
    bare.newLayer(.text)
    #expect(bare.selectedLayer?.text == HaloTextContent())
}
