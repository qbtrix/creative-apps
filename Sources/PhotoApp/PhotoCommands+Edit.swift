// PhotoCommands+Edit.swift: Photo's Edit menu items: Undo and Redo named for
// the edit, then Delete Selection and Fill Selection after the pasteboard group.
import SwiftUI

extension PhotoCommands {
    @CommandsBuilder var editMenu: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button(menu.undoTitle) { menu.perform(.undo) }.keyboardShortcut("z").disabled(!menu.canUndo)
            Button(menu.redoTitle) { menu.perform(.redo) }.keyboardShortcut("z", modifiers: [.command, .shift])
                .disabled(!menu.canRedo)
        }
        CommandGroup(after: .pasteboard) {
            Divider()
            Button("Delete Selection") { menu.perform(.deleteSelection) }.disabled(!menu.canEditSelection)
            Button("Fill Selection") { menu.perform(.fillSelection) }.disabled(!menu.canEditSelection)
        }
    }
}
