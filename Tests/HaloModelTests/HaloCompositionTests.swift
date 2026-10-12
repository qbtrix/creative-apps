// HaloCompositionTests.swift: composition settings validation and HaloProject's
// duplicate, rename and delete. Runs on Linux and macOS.
import HaloModel
import Testing

@Test(arguments: [
    (0, 1080, 30, 10.0, false), (1, 1, 24, 0.5, true), (8192, 8192, 60, 10, true), (8193, 1080, 30, 10, false),
    (1920, -5, 30, 10, false), (1920, 1080, 25, 10, true), (1920, 1080, 29, 10, false), (1920, 1080, 30, 0, false),
    (1920, 1080, 30, -1, false), (1920, 1080, 30, .nan, false), (1920, 1080, 30, 86_400, true),
] as [(Int, Int, Int, Double, Bool)])
func settingsValidation(width: Int, height: Int, fps: Int, seconds: Double, valid: Bool) {
    let settings = CompositionSettings(name: "Intro", width: width, height: height, framesPerSecond: fps, durationSeconds: seconds)
    #expect(settings.isValid == valid)
    #expect(settings.problems.isEmpty == valid)
}

@Test func invalidWidthSaysWhy() {
    let settings = CompositionSettings(name: "Intro", width: 0)
    #expect(settings.problems == ["Width must be 1 to 8192 pixels."])
    #expect(settings.durationFrames == nil)
    #expect(!CompositionSettings(name: "  ").isValid)
    var project = HaloProject()
    #expect(project.newComposition(settings) == false)
    #expect(project.compositions.isEmpty)
}

@Test func newCompositionUsesTheSettings() {
    var project = HaloProject()
    let settings = CompositionSettings(name: " Intro ", width: 1280, height: 720, framesPerSecond: 24, durationSeconds: 2.5)
    #expect(project.newComposition(settings) == true)
    let comp = project.selectedComposition
    #expect(comp?.name == "Intro")
    #expect(comp?.width == 1280)
    #expect(comp?.height == 720)
    #expect(comp?.framesPerSecond == 24)
    #expect(comp?.durationFrames == 60)
}

@Test func suggestedSettingsAreNamedAfterTheNextComposition() {
    var project = HaloProject()
    #expect(project.suggestedSettings == CompositionSettings(name: "Comp 1"))
    project.newComposition()
    #expect(project.suggestedSettings.name == "Comp 2")
}

@Test func duplicateGetsAUniqueCopyNameAndItsOwnLayers() {
    var project = HaloProject()
    project.newComposition()
    project.newLayer(.solid)
    #expect(project.duplicateComposition("comp-1") == true)
    #expect(project.duplicateComposition("comp-1") == true)
    #expect(project.compositions.map(\.name) == ["Comp 1", "Comp 1 copy 2", "Comp 1 copy"])
    #expect(project.compositions.map(\.id) == ["comp-1", "comp-3", "comp-2"])
    #expect(project.selectedCompositionID == "comp-3")
    #expect(project.selectedComposition?.layers.map(\.id) == ["comp-3-layer-1"])
    #expect(project.selectedComposition?.layers.map(\.name) == ["Solid 1"])
    #expect(project.duplicateComposition("comp-9") == false)
}

@Test func renameTrimsAndRefusesEmptyOrTakenNames() {
    var project = HaloProject()
    project.newComposition()
    project.newComposition()
    #expect(project.renameComposition("comp-1", to: "  Title  ") == true)
    #expect(project.renameComposition("comp-1", to: "   ") == false)
    #expect(project.renameComposition("comp-2", to: "Title") == false)
    #expect(project.renameComposition("comp-9", to: "Other") == false)
    #expect(project.compositions.map(\.name) == ["Title", "Comp 2"])
}

@Test func deletingTheLastCompositionIsRefused() {
    var project = HaloProject()
    project.newComposition()
    #expect(!project.canDeleteComposition)
    #expect(project.deleteComposition("comp-1") == false)
    #expect(project.compositions.map(\.id) == ["comp-1"])
}

@Test func deletingTheSelectedCompositionSelectsANeighborAndNeverReusesIds() {
    var project = HaloProject()
    project.newComposition()
    project.newComposition()
    project.newComposition()
    project.selectComposition("comp-2")
    #expect(project.deleteComposition("comp-2") == true)
    #expect(project.selectedCompositionID == "comp-3")
    #expect(project.deleteComposition("comp-3") == true)
    #expect(project.selectedCompositionID == "comp-1")
    project.newComposition()
    #expect(project.compositions.map(\.id) == ["comp-1", "comp-4"])
    #expect(project.compositions.map(\.name) == ["Comp 1", "Comp 4"])
    #expect(project.deleteComposition("comp-4") == true)
    #expect(project.selectedCompositionID == "comp-1")
}
