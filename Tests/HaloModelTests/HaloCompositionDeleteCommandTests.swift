// HaloCompositionDeleteCommandTests.swift: Composition > Delete never deletes
// while a text field (the rename field) has focus. Runs on Linux and macOS.
import HaloModel
import Testing

@Test func deleteWhileRenamingEditsTextAndKeepsTheComposition() {
    var project = HaloProject()
    project.newComposition()
    project.newComposition()
    #expect(project.compositionDeleteCommand(editingText: true) == .editText)
    #expect(project.compositions.count == 2)
}

@Test func deleteWithoutTextFocusDeletesTheSelectedComposition() {
    var project = HaloProject()
    project.newComposition()
    project.newComposition()
    let selected = project.selectedCompositionID
    #expect(selected == "comp-2")
    #expect(project.compositionDeleteCommand(editingText: false) == .delete("comp-2"))
}

@Test func deleteIsUnavailableWithOneCompositionOrNone() {
    var project = HaloProject()
    #expect(project.compositionDeleteCommand(editingText: false) == .unavailable)
    project.newComposition()
    #expect(project.compositionDeleteCommand(editingText: false) == .unavailable)
    #expect(project.compositionDeleteCommand(editingText: true) == .editText)
}
