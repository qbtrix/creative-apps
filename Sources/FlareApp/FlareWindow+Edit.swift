// FlareWindow+Edit.swift: the router's edit area (FlareWindow+Router.swift).
// Undo and Redo step the document's history, so ⌘Z and the toolbar keep
// working; Delete removes the selected keyframes (the Delete key reaches this
// menu item, not the timeline strip); the pasteboard and arrange intents wait
// for F18 and say so.
import FlareModel

extension FlareWindow {
    /// Acts on an edit intent: Undo, Redo and Delete (keyframes), for now.
    func performEdit(_ intent: FlareIntent.Edit) {
        switch intent {
        case .undo: model.undo()
        case .redo: model.redo()
        case .delete: model.deleteSelection()
        default: break
        }
    }

    /// Why an edit intent can't act now; nil for Undo or Redo while there is a step, Delete while keys are selected.
    func editHelp(_ intent: FlareIntent.Edit) -> String? {
        switch intent {
        case .undo: model.canUndo ? nil : "Nothing to undo."
        case .redo: model.canRedo ? nil : "Nothing to redo."
        case .delete: model.deleteHelp
        default: "Not built yet (F18)."
        }
    }
}
