// DesignDirtyTests.swift: the document knows when it is unsaved (#270, files-history
// FH-2). Every history step carries a serial that only increases, and the save
// marks the current one; the document is dirty when the current serial is not the
// saved one, so undoing back to the save reads clean, while a new edit after an
// undo, the 100-step cap and a coalescing run never do. Runs on Linux and macOS.
import DesignModel
import Testing

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

private let savedURL = URL(fileURLWithPath: "/tmp/Poster.design")

/// A new file holding one rectangle, saved, with the rectangle selected.
private func savedWithRectangle() throws -> (DesignWorkspace, String) {
    var workspace = openDesign()
    let id = try workspace.addNode(.rectangle, frame: rc(0, 0, 10, 10), in: "node-1")
    workspace.selectItem(id)
    workspace.didSave(to: savedURL)
    return (workspace, id)
}

@Test func aNewFileIsClean() {
    let workspace = openDesign()
    #expect(!workspace.isDirty)
}

@Test func nothingOpenIsClean() {
    #expect(!DesignWorkspace().isDirty)
}

@Test func oneEditIsDirty() throws {
    var workspace = openDesign()
    try workspace.addNode(.rectangle, frame: rc(0, 0, 10, 10), in: "node-1")
    #expect(workspace.isDirty)
}

@Test func didSaveIsClean() throws {
    let (workspace, _) = try savedWithRectangle()
    #expect(!workspace.isDirty)
    #expect(workspace.documentURL == savedURL)
}

@Test func undoPastTheSaveIsDirtyAndRedoBackIsClean() throws {
    var (workspace, _) = try savedWithRectangle()
    workspace.undo()
    #expect(workspace.isDirty)
    workspace.redo()
    #expect(!workspace.isDirty)
}

@Test func undoAnEditAfterTheSaveIsClean() throws {
    var (workspace, _) = try savedWithRectangle()
    workspace.addPage()
    #expect(workspace.isDirty)
    workspace.undo()
    #expect(!workspace.isDirty)
    workspace.redo()
    #expect(workspace.isDirty)
}

@Test func undoPastTheSaveThenANewEditIsDirty() throws {
    var (workspace, _) = try savedWithRectangle()
    workspace.undo()
    workspace.addPage()
    #expect(workspace.isDirty)
    workspace.undo()
    #expect(workspace.isDirty)
}

@Test func editsPastTheHistoryCapAfterASaveAreDirty() {
    var workspace = openDesign()
    workspace.didSave(to: savedURL)
    for _ in 0..<101 { workspace.addPage() }
    #expect(workspace.isDirty)
    // Undo as far as the capped history goes: the save's state was dropped, so still dirty.
    while workspace.canUndo { workspace.undo() }
    #expect(workspace.pages.count == 2)
    #expect(workspace.isDirty)
}

@Test func aCoalescingRunAfterASaveIsDirtyAndOneUndoIsClean() throws {
    var (workspace, id) = try savedWithRectangle()
    for _ in 0..<5 { workspace.nudge(.right, shift: false) }
    #expect(workspace.frame(id) == rc(5, 0, 10, 10))
    #expect(workspace.isDirty)
    // The save ended the run, so the five nudges are one step of their own.
    workspace.undo()
    #expect(workspace.frame(id) == rc(0, 0, 10, 10))
    #expect(!workspace.isDirty)
}

@Test func aRunInterruptedByASaveIsTwoSteps() throws {
    var (workspace, id) = try savedWithRectangle()
    workspace.nudge(.right, shift: false)
    workspace.didSave(to: savedURL)
    workspace.nudge(.right, shift: false)
    #expect(workspace.isDirty)
    workspace.undo()
    #expect(workspace.frame(id) == rc(1, 0, 10, 10))
    #expect(!workspace.isDirty)
}

@Test func aNewFileOverAnEditedFileIsClean() throws {
    var workspace = openDesign()
    try workspace.addNode(.rectangle, frame: rc(0, 0, 10, 10), in: "node-1")
    workspace.newFile()
    #expect(!workspace.isDirty)
    // Undo New File brings back the edited, never-saved document.
    workspace.undo()
    #expect(workspace.isDirty)
}
