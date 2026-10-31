// LibraryWindow+Edit.swift: the edit area (spine). Undo and Redo name the
// catalog's top step and disable when there is none, and a step that moved
// develop settings redraws the loupe and those thumbnails; Select All and Deselect
// change the selection and disable when there is nothing to change; Load
// Sample Photos fills the catalog, except over a newer catalog. Each runs a
// `LibraryAction` (LibraryActions.swift), disabled while its `help` is set.
import LibraryModel
import SwiftUI

final class EditAreaState {}

extension LibraryWindow {
    var editMenu: LibraryMenu.Edit {
        LibraryMenu.Edit(
            undo: undoing(.undo),
            redo: undoing(.redo),
            undoTitle: model.undoTitle ?? "Undo",
            redoTitle: model.redoTitle ?? "Redo",
            selectAll: act(.selectAll),
            deselect: act(.deselect),
            loadSamples: act(.loadSamples))
    }

    /// Undo or Redo; a step that changed develop settings redraws the loupe and those photos' thumbnails.
    private func undoing(_ action: LibraryAction) -> (@MainActor () -> Void)? {
        enabled(model.help(action) == nil) {
            try? model.run(action)
            if !model.developChangedIDs.isEmpty { developFinish(model.developChangedIDs) }
        }
    }

    /// The menu action that runs `action`, nil (so the item disables) while the catalog refuses it.
    func act(_ action: LibraryAction) -> (@MainActor () -> Void)? {
        enabled(model.help(action) == nil) { try? model.run(action) }
    }
}
