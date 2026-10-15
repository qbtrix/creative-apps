// HaloWindow+Edit.swift: the history area's routes (Undo, Redo) and hook.
// Edit > Undo ⌘Z and Redo ⇧⌘Z (HaloEditMenu) arrive here as .undo and
// .redo and call the Model's `undo()` and `redo()` (HaloHistory.swift), which
// step the whole document and do nothing when there is no step. The menu
// titles each for its step ("Undo New Layer") and disables it with
// `model.unavailableHelp(for:)` ("Nothing to undo.") as help. The hook adds
// nothing.
import HaloModel
import SwiftUI

extension HaloWindow {
    func editPerform(_ command: HaloCommand) {
        switch command {
        case .undo: model.undo()
        case .redo: model.redo()
        default: break
        }
    }

    func editScene(_ content: some View) -> some View { content }
}
