// FlareWindow+Edit.swift: the router's edit area (FlareWindow+Router.swift).
// Undo and Redo step the document's history, so ⌘Z and the toolbar keep
// working; the pasteboard and arrange intents wait for F18 and say so.
import FlareModel

extension FlareWindow {
    /// Acts on an edit intent: Undo and Redo only, for now.
    func performEdit(_ intent: FlareIntent.Edit) {
        switch intent {
        case .undo: model.undo()
        case .redo: model.redo()
        default: break
        }
    }

    /// Why an edit intent can't act now; nil for Undo or Redo while there is a step.
    func editHelp(_ intent: FlareIntent.Edit) -> String? {
        switch intent {
        case .undo: model.canUndo ? nil : "Nothing to undo."
        case .redo: model.canRedo ? nil : "Nothing to redo."
        default: "Not built yet (F18)."
        }
    }
}
