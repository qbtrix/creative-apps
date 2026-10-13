// DesignUndoNewFileURLTests.swift: documentURL follows the document through
// Undo and Redo of New File, so Save after Undo writes the original file
// (#436). Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import DesignModel
import Testing

private let fileA = URL(fileURLWithPath: "/tmp/a.design")
private let fileC = URL(fileURLWithPath: "/tmp/c.design")

/// a.design, opened from disk, with a rectangle added after opening.
private func openedA() throws -> DesignWorkspace {
    var source = openDesign()
    try source.addNode(.rectangle, frame: rc(10, 10, 50, 50), in: "node-1")
    var workspace = DesignWorkspace()
    try workspace.open(source.fileData(), at: fileA)
    try workspace.addNode(.ellipse, frame: rc(70, 10, 40, 40), in: "node-1")
    return workspace
}

@Test func openAndSaveSetTheDocumentURL() throws {
    var workspace = try openedA()
    #expect(workspace.documentURL == fileA)
    workspace.didSave(to: fileC)
    #expect(workspace.documentURL == fileC)
    workspace.newFile()
    #expect(workspace.documentURL == nil)
}

@Test func undoNewFileRestoresTheFileAndRedoClearsIt() throws {
    var workspace = try openedA()
    let original = workspace.pages
    workspace.newFile()
    #expect(workspace.documentURL == nil)
    workspace.undo()
    #expect(workspace.pages == original)
    #expect(workspace.documentURL == fileA)
    workspace.redo()
    #expect(workspace.documentURL == nil)
    workspace.undo()
    #expect(workspace.documentURL == fileA)
}

@Test func aNewFileSavedBeforeUndoGetsItsLocationBackOnRedo() throws {
    var workspace = try openedA()
    workspace.newFile()
    workspace.didSave(to: fileC)
    workspace.undo()
    #expect(workspace.documentURL == fileA)
    workspace.redo()
    #expect(workspace.documentURL == fileC)
}

@Test func undoOfAnOrdinaryEditKeepsTheLocation() throws {
    var workspace = try openedA()
    workspace.didSave(to: fileC)
    workspace.undo()
    #expect(workspace.documentURL == fileC)
    workspace.redo()
    #expect(workspace.documentURL == fileC)
}

@Test func undoIgnoredMidDragKeepsTheLocation() throws {
    var workspace = try openedA()
    workspace.newFile()
    workspace.selectTool(.rectangle)
    workspace.drag(from: pt(100, 100), to: pt(200, 200), modifiers: [])
    workspace.undo()
    #expect(workspace.documentURL == nil)
    workspace.endDrag()
    workspace.undo()
    workspace.undo()
    #expect(workspace.documentURL == fileA)
}
