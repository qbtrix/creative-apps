// DesignUndoTargetTests.swift: where Edit > Undo goes (a focused text field's own
// undo, or the document's, #275), and what the window reads from the saved state:
// Open is clean, a refused edit records nothing, the close prompt names the file,
// and the save state text (files-history FH-2). Runs on Linux and macOS.
import DesignModel
import Testing

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

@Test func aFocusedFieldTakesUndo() {
    #expect(openDesign().undoTarget(textFieldFocused: true) == .field)
}

@Test func otherwiseTheDocumentTakesUndo() {
    #expect(openDesign().undoTarget(textFieldFocused: false) == .document)
    #expect(DesignWorkspace().undoTarget(textFieldFocused: false) == .document)
}

@Test func openIsClean() throws {
    var source = openDesign()
    try source.addNode(.rectangle, frame: rc(0, 0, 10, 10), in: "node-1")
    let data = try source.fileData()
    var workspace = DesignWorkspace()
    try workspace.open(data, at: URL(fileURLWithPath: "/tmp/Opened.design"))
    #expect(!workspace.isDirty)
    #expect(workspace.closePrompt == nil)
}

@Test func aRefusedEditLeavesItClean() {
    var workspace = openDesign()
    #expect(throws: DesignTreeError.emptyName) { try workspace.renamePage("page-1", to: "  ") }
    #expect(!workspace.isDirty)
}

@Test func theClosePromptIsNilWhenClean() {
    #expect(openDesign().closePrompt == nil)
    #expect(DesignWorkspace().closePrompt == nil)
}

@Test func theClosePromptNamesUntitledForAFixture() throws {
    var workspace = try #require(DesignFixtures.named("cards"))
    workspace.addPage()
    #expect(workspace.closePrompt == "Do you want to save the changes you made to “Untitled”?")
}

@Test func theClosePromptNamesTheSavedFile() {
    var workspace = openDesign()
    workspace.didSave(to: URL(fileURLWithPath: "/tmp/Poster.design"))
    workspace.addPage()
    #expect(workspace.closePrompt == "Do you want to save the changes you made to “Poster.design”?")
}

@Test func theSaveStateReadsSavedEditedOrNothing() {
    #expect(DesignWorkspace().saveStateText == nil)
    var workspace = openDesign()
    workspace.didSave(to: URL(fileURLWithPath: "/tmp/Poster.design"))
    #expect(workspace.saveStateText == "Saved")
    workspace.addPage()
    #expect(workspace.saveStateText == "Edited")
    workspace.didSave(to: URL(fileURLWithPath: "/tmp/Poster.design"))
    #expect(workspace.saveStateText == "Saved")
}
