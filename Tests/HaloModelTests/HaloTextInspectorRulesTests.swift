// HaloTextInspectorRulesTests.swift (text-layers fix round): the TEXT
// section's decisions on `empty` with the fake services. A blank commit's
// refusal is owned by TEXT and shows only under the field (#2175, #2181); a
// draft typed for one text layer neither shows on nor commits to another
// (#2177); the size bar's drag range puts 72 and 96 px clear of its label
// while typing keeps the whole size range (#2180). Runs on Linux and macOS.
import HaloModel
import Testing

/// `empty` with two text layers: A reading "Hello", then B selected.
private func twoTextLayers() throws -> (project: HaloProject, a: String, b: String) {
    var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("empty")))
    project.newLayer(.text)
    project.setText("Hello")
    let a = try #require(project.selectedLayerID)
    project.newLayer(.text)
    let b = try #require(project.selectedLayerID)
    return (project, a, b)
}

@Test func blankTextRefusalShowsOnlyUnderTheField() throws {
    var (project, _, _) = try twoTextLayers()
    project.setText("   ")
    let refusal = try #require(project.refusal)
    #expect(HaloProject.textOwns(refusal))
    #expect(project.textRefusal(at: "halo.inspector.text.string") == refusal)
    #expect(project.textRefusal(at: "halo.inspector.text.size") == nil)
    #expect(project.textRefusal(at: "halo.inspector.text.color") == nil)
}

@Test func textOwnsOnlyItsControls() {
    let ids = ["halo.inspector.text.string", "halo.inspector.text.size", "halo.inspector.text.color"]
    #expect(HaloProject.textControls == ids)
    for id in ids { #expect(HaloProject.textOwns(HaloRefusal(control: id, message: "m"))) }
    for id in ["halo.inspector.row.rotation", "halo.inspector.parent", "halo.inspector"] {
        #expect(!HaloProject.textOwns(HaloRefusal(control: id, message: "m")))
    }
}

@Test func aDraftStaysWithItsLayer() throws {
    var (project, a, b) = try twoTextLayers()
    let draft = HaloTextDraft(layerID: b, words: "Stale")
    #expect(project.textFieldWords(draft: draft) == "Stale")
    #expect(draft.commit(on: project) == .setText("Stale"))
    project.selectLayer(a)
    #expect(project.textFieldWords(draft: draft) == "Hello")
    #expect(draft.commit(on: project) == nil)
    #expect(project.textFieldWords(draft: nil) == "Hello")
}

@Test func noFieldWordsWithoutATextLayer() throws {
    var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("empty")))
    project.newLayer(.solid)
    let id = try #require(project.selectedLayerID)
    #expect(project.textFieldWords(draft: HaloTextDraft(layerID: id, words: "x")) == nil)
}

@Test func usualSizesSitClearOfTheSizeBarLabel() {
    let bar = HaloTextContent.sizeBarRange
    for size in [72.0, 96] {
        let fraction = (HaloTextContent.sizeBarPosition(size) - bar.lowerBound) / (bar.upperBound - bar.lowerBound)
        #expect(fraction >= 0.25, "\(size) px sits at \(fraction) of the bar")
    }
    #expect(HaloTextContent.fontSizeRange.contains(bar.lowerBound) && HaloTextContent.fontSizeRange.contains(bar.upperBound))
    #expect(HaloTextContent.fontSizeRange.upperBound > bar.upperBound)
    #expect(HaloTextContent.sizeBarPosition(600) == bar.upperBound)
    #expect(HaloTextContent.sizeBarPosition(0) == bar.lowerBound)
    #expect(HaloTextContent.sizeBarPosition(.nan) == bar.lowerBound)
    #expect(HaloTextContent.sizeBarPosition(96) == 96)
}
