// DesignNewFileUndoTests.swift: New File empties the window's undo stack, so a
// Delete Page step from the old file shows neither Undo nor Redo (#124).
// macOS only.
import Foundation
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignNewFileUndoTests {
    @Test func newFileDisablesUndoAndRedo() {
        let undoManager = UndoManager()
        undoManager.groupsByEvent = false
        for _ in 0..<2 {
            undoManager.beginUndoGrouping()
            // Like the window's Delete Page, undoing registers the redo step.
            undoManager.registerUndo(withTarget: undoManager) { $0.registerUndo(withTarget: $0) { _ in } }
            undoManager.setActionName("Delete Page")
            undoManager.endUndoGrouping()
        }
        undoManager.undo()
        #expect(undoManager.canUndo && undoManager.canRedo)
        var opened = false
        DesignUndo.startNewFile(undoManager) { opened = true }
        #expect(opened)
        #expect(!undoManager.canUndo)
        #expect(!undoManager.canRedo)
    }

    @Test func newFileWithoutAnUndoManagerStillOpens() {
        var opened = false
        DesignUndo.startNewFile(nil) { opened = true }
        #expect(opened)
    }
}
