// DesignUndoNewFileUneditedTests.swift: New File over a saved file whose pages
// already match a fresh file still records one "New File" step, because it
// clears the file's location; Undo puts the location back and Redo clears it
// again (#492). Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import DesignModel
import Testing

private let fileC = URL(fileURLWithPath: "/tmp/c.design")

@Test func newFileOverAnUneditedSavedFileIsOneUndoStepThatKeepsItsLocation() {
    var workspace = DesignWorkspace()
    workspace.newFile()
    workspace.didSave(to: fileC)
    let pages = workspace.pages
    workspace.newFile()
    #expect(workspace.documentURL == nil)
    #expect(workspace.undoActionName == "Undo New File")
    #expect(workspace.undoSwapsDocument)
    workspace.undo()
    #expect(workspace.documentURL == fileC)
    #expect(workspace.pages == pages)
    #expect(!workspace.canUndo)
    workspace.redo()
    #expect(workspace.documentURL == nil)
    #expect(workspace.pages == pages)
    #expect(!workspace.canRedo)
}

@Test func newFileOverAnUneditedOpenedFileBringsItsLocationBackOnUndo() throws {
    var fresh = DesignWorkspace()
    fresh.newFile()
    var workspace = DesignWorkspace()
    try workspace.open(fresh.fileData(), at: fileC)
    let pages = workspace.pages
    workspace.newFile()
    #expect(workspace.documentURL == nil)
    workspace.undo()
    #expect(workspace.documentURL == fileC)
    #expect(workspace.pages == pages)
    workspace.redo()
    #expect(workspace.documentURL == nil)
}

@Test func newFileOverAnUneditedUnsavedFileStillRecordsNothing() {
    var workspace = DesignWorkspace()
    workspace.newFile()
    workspace.newFile()
    #expect(!workspace.canUndo)
    #expect(workspace.documentURL == nil)
}
