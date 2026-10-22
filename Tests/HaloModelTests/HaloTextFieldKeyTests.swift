// HaloTextFieldKeyTests.swift (core-loop CL-z, #4310): the TEXT field's key,
// the selected layer and its stored words, on `empty` with the fake
// services. An Undo or Redo that changes the words gives a new key, so the
// inspector drops its draft, ends editing and shows the stored words: after
// Undo the field reads "Text", after Redo "Hello" again. Runs on Linux and macOS.
import HaloModel
import Testing

@Test func undoAndRedoOfTheWordsChangeTheFieldKey() throws {
    var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("empty")))
    project.newLayer(.text)
    let fresh = project.textFieldKey
    #expect(fresh.words == "Text")
    project.setText("Hello")
    let typed = project.textFieldKey
    #expect(typed != fresh)
    #expect(typed == HaloTextFieldKey(layerID: project.selectedLayerID, words: "Hello"))

    project.undo()
    #expect(project.textFieldKey == fresh)
    #expect(project.textFieldWords(draft: nil) == "Text")
    project.redo()
    #expect(project.textFieldKey == typed)
    #expect(project.textFieldWords(draft: nil) == "Hello")
}

@Test func aNewSelectionChangesTheFieldKey() throws {
    var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("empty")))
    project.newLayer(.text)
    let first = try #require(project.selectedLayerID)
    let one = project.textFieldKey
    project.newLayer(.text)
    #expect(project.textFieldKey != one)
    #expect(project.textFieldKey.words == "Text")
    project.selectLayer(first)
    #expect(project.textFieldKey == one)
}

@Test func noWordsInTheKeyWithoutATextLayer() throws {
    var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("empty")))
    project.newLayer(.solid)
    #expect(project.textFieldKey == HaloTextFieldKey(layerID: project.selectedLayerID, words: nil))
}
