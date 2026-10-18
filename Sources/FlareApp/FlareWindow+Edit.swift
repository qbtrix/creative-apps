// FlareWindow+Edit.swift: the router's edit area (FlareWindow+Router.swift), stage-edit SE-3.
// Undo and Redo step the document's history. Cut, Copy and Paste carry the Model's layer bytes through
// FlarePasteboard, the system pasteboard under the suite's `flareLayers` type; Duplicate, Select All and
// Deselect call the Model. Delete removes the selected keyframes while there are any (the Delete key reaches
// this menu item, not the timeline strip), else the selected items or layers. Object > Bring Forward and
// Send Backward move the selected layer one place. `editHelp(_:in:pasteboard:)` is static so the stage's
// context menu (FlareStageContextMenu.swift) disables its items with the same reasons.
import FlareModel
import Foundation

extension FlareWindow {
    /// Acts on an edit intent.
    func performEdit(_ intent: FlareIntent.Edit) {
        switch intent {
        case .undo: model.undo()
        case .redo: model.redo()
        case .cut: FlarePasteboard.write(model.cut())
        case .copy: FlarePasteboard.write(model.copy())
        case .paste: model.paste(FlarePasteboard.read())
        case .duplicate: model.duplicate()
        case .delete:
            if model.deleteHelp == nil { model.deleteSelection() } else { model.delete() }
        case .selectAll: model.selectAll()
        case .deselect: model.deselect()
        case .bringForward: model.bringForward()
        case .sendBackward: model.sendBackward()
        }
    }

    /// Why an edit intent can't act now; Paste reads the system pasteboard.
    func editHelp(_ intent: FlareIntent.Edit) -> String? {
        Self.editHelp(intent, in: model, pasteboard: intent == .paste ? FlarePasteboard.read() : nil)
    }

    /// Why `intent` can't act on `model`; nil when it can. `pasteboard` is what Paste would insert.
    static func editHelp(_ intent: FlareIntent.Edit, in model: FlareWorkspace, pasteboard: Data?) -> String? {
        switch intent {
        case .undo: model.canUndo ? nil : "Nothing to undo."
        case .redo: model.canRedo ? nil : "Nothing to redo."
        case .cut: model.editHelp(.cut)
        case .copy: model.editHelp(.copy)
        case .paste: model.editHelp(.paste, pasteboard: pasteboard)
        case .duplicate: model.editHelp(.duplicate)
        case .delete: model.deleteHelp == nil ? nil : model.editHelp(.delete)
        case .selectAll: model.editHelp(.selectAll)
        case .deselect: model.editHelp(.deselect)
        case .bringForward: model.orderHelp(forward: true)
        case .sendBackward: model.orderHelp(forward: false)
        }
    }
}
