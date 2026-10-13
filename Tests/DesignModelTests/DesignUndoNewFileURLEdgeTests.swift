// DesignUndoNewFileURLEdgeTests.swift: adversarial cases for documentURL riding
// Undo and Redo of New File (#436): chains of New File, Save As between steps,
// ordinary edits on either side of the swap, Open clearing the history, and a
// refused file keeping the location. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import DesignModel
import Testing

private let fileA = URL(fileURLWithPath: "/tmp/edge-a.design")
private let fileB = URL(fileURLWithPath: "/tmp/edge-b.design")
private let fileC = URL(fileURLWithPath: "/tmp/edge-c.design")

/// edge-a.design, opened from disk, holding a rectangle so it differs from a new file.
private func openedA() throws -> DesignWorkspace {
    var source = openDesign()
    try source.addNode(.rectangle, frame: rc(10, 10, 50, 50), in: "node-1")
    var workspace = DesignWorkspace()
    try workspace.open(source.fileData(), at: fileA)
    return workspace
}

@Test func eachNewFileInAChainGetsItsOwnLocationBack() throws {
    var workspace = try openedA()
    workspace.newFile()
    try workspace.addNode(.ellipse, frame: rc(20, 20, 30, 30), in: "node-1")
    workspace.didSave(to: fileB)
    workspace.newFile()
    #expect(workspace.documentURL == nil)
    workspace.undo()
    #expect(workspace.documentURL == fileB)
    workspace.undo()
    #expect(workspace.documentURL == fileB)
    workspace.undo()
    #expect(workspace.documentURL == fileA)
    // The second document was saved to edge-b.design, so its earlier states belong there too.
    workspace.redo()
    #expect(workspace.documentURL == fileB)
    workspace.redo()
    #expect(workspace.documentURL == fileB)
    workspace.redo()
    #expect(workspace.documentURL == nil)
    workspace.undo()
    workspace.undo()
    #expect(workspace.documentURL == fileB)
}

@Test func saveAsAfterUndoingNewFileIsWhatUndoRestoresNext() throws {
    var workspace = try openedA()
    workspace.newFile()
    workspace.undo()
    workspace.didSave(to: fileC)
    workspace.redo()
    #expect(workspace.documentURL == nil)
    workspace.undo()
    #expect(workspace.documentURL == fileC)
}

@Test func anEditAfterUndoingNewFileKeepsTheRestoredLocation() throws {
    var workspace = try openedA()
    workspace.newFile()
    workspace.undo()
    try workspace.addNode(.ellipse, frame: rc(70, 10, 40, 40), in: "node-1")
    #expect(!workspace.canRedo)
    #expect(workspace.documentURL == fileA)
    workspace.undo()
    #expect(workspace.documentURL == fileA)
}

@Test func undoingEditsMadeInTheNewFileKeepsItsSavedLocation() throws {
    var workspace = try openedA()
    workspace.newFile()
    workspace.didSave(to: fileB)
    try workspace.addNode(.ellipse, frame: rc(20, 20, 30, 30), in: "node-1")
    workspace.undo()
    #expect(workspace.documentURL == fileB)
    workspace.undo()
    #expect(workspace.documentURL == fileA)
}

@Test func openingAFileDropsTheNewFileStepAndItsLocation() throws {
    var workspace = try openedA()
    workspace.newFile()
    var other = openDesign()
    try other.addNode(.rectangle, frame: rc(0, 0, 5, 5), in: "node-1")
    try workspace.open(other.fileData(), at: fileB)
    #expect(workspace.documentURL == fileB)
    #expect(!workspace.canUndo)
    workspace.undo()
    #expect(workspace.documentURL == fileB)
}

@Test func aRefusedFileKeepsTheLocation() throws {
    var workspace = try openedA()
    #expect(throws: DesignFileError.self) { try workspace.open(Data("not a design".utf8), at: fileB) }
    #expect(workspace.documentURL == fileA)
}

@Test func undoIgnoredWhileEditingTextKeepsTheLocation() throws {
    var workspace = try openedA()
    workspace.newFile()
    workspace.gesture(.text, pt(100, 100), pt(100, 100))
    #expect(workspace.editingTextID != nil)
    workspace.undo()
    #expect(workspace.documentURL == nil)
    workspace.commitTextEdit()
    while workspace.canUndo { workspace.undo() }
    #expect(workspace.documentURL == fileA)
}

@Test func manyRoundTripsKeepThePairing() throws {
    var workspace = try openedA()
    workspace.newFile()
    workspace.didSave(to: fileB)
    for _ in 0..<50 {
        workspace.undo()
        #expect(workspace.documentURL == fileA)
        workspace.redo()
        #expect(workspace.documentURL == fileB)
    }
}
