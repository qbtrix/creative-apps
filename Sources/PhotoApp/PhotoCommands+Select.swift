// PhotoCommands+Select.swift: Photo's Select menu: All (Command-A, see
// PhotoMenu.selectAll) and Deselect.
import SuiteUI
import SwiftUI

extension PhotoCommands {
    var selectMenu: some Commands {
        CommandMenu("Select") {
            // Off only for a focused window with no image: a sheet's window may
            // not carry the focused value, and its field still needs Command-A (PhotoMenuState).
            menu.item("select.all", shortcut: KeyboardShortcut("a")) { menu.selectAll() }
            menu.item("select.deselect", shortcut: KeyboardShortcut("d")) { menu.perform(.deselect) }
        }
    }
}
