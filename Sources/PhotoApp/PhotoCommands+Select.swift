// PhotoCommands+Select.swift: Photo's Select menu: All (Command-A, see
// PhotoMenu.selectAll) and Deselect.
import SwiftUI

extension PhotoCommands {
    var selectMenu: some Commands {
        CommandMenu("Select") {
            // Off only for a focused window with no image: a sheet's window may
            // not carry the focused value, and its field still needs Command-A.
            Button("All") { menu.selectAll() }.keyboardShortcut("a").disabled(focused.map { !$0.hasImage } ?? false)
            Button("Deselect") { menu.perform(.deselect) }.keyboardShortcut("d").disabled(!menu.canDeselect)
        }
    }
}
