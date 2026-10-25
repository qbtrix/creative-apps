// HaloNewCompositionSetupTests.swift (document-setup DS-15, slice DS-z): New Composition from the shared
// New Document sheet's setup. A valid setup adds a composition named after the next id, selected, as one
// "New Composition" step; a setup with a problem adds nothing. Linux and macOS.
@testable import HaloModel
import SuiteKernel
import Testing

@Suite struct HaloNewCompositionSetupTests {
    @Test func setupAddsSelectedCompositionInOneStep() throws {
        var project = HaloCompositionSettingsTests.keyed(layers: false)
        let setup = DocumentSetup(width: 1080, height: 1920, background: .color(hex: "#000080"), frameRate: FrameRate(whole: 24),
                                  durationSeconds: 2)
        let added = project.newComposition(setup)
        #expect(added)
        let comp = try #require(project.selectedComposition)
        #expect(comp.name == "Comp 2" && comp.id != "comp-1", "the new composition isn't the next one")
        #expect(comp.width == 1080 && comp.height == 1920 && comp.frameRate == FrameRate(whole: 24))
        #expect(comp.durationFrames == 48 && comp.background == .color(hex: "#000080"))
        #expect(project.document.compositions.count == 2)
        #expect(project.history.undoTitle == "Undo New Composition")
        project.undo()
        #expect(project.document.compositions.count == 1, "one undo didn't remove the new composition")
    }

    @Test func setupWithAProblemAddsNothing() {
        var project = HaloCompositionSettingsTests.keyed(layers: false)
        let narrow = project.newComposition(DocumentSetup(width: 0, height: 1080))
        let empty = project.newComposition(DocumentSetup(width: 1920, height: 1080, durationSeconds: 0))
        #expect(!narrow && !empty, "a setup with a problem made a composition")
        #expect(project.document.compositions.count == 1 && project.history.undoTitle == nil)
    }
}
