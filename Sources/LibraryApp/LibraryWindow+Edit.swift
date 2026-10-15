// LibraryWindow+Edit.swift: the edit area (spine). Undo and Redo name the
// catalog's top step and disable when there is none; Select All and Deselect
// change the selection and disable when there is nothing to change; Load
// Sample Photos fills the catalog.
import LibraryModel
import SwiftUI

final class EditAreaState {}

extension LibraryWindow {
    var editMenu: LibraryMenu.Edit {
        LibraryMenu.Edit(
            undo: enabled(model.undoTitle != nil) { model.undo() },
            redo: enabled(model.redoTitle != nil) { model.redo() },
            undoTitle: model.undoTitle ?? "Undo",
            redoTitle: model.redoTitle ?? "Redo",
            selectAll: enabled(!model.order.isEmpty) { model.select(Set(model.order)) },
            deselect: enabled(!model.selection.isEmpty) { model.select([]) },
            loadSamples: { model.loadSamples() })
    }
}
