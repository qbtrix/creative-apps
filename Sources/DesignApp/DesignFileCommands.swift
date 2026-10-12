// DesignFileCommands.swift: Design's File > New File (⌘N). It replaces the
// default New Item group, which opened a blank window, and calls the same
// DesignWorkspace.newFile() as the toolbar button. The window publishes the
// action as a focused scene value, so the item disables with no window focused.
import SwiftUI

extension FocusedValues {
    /// Opens a new file in the focused window.
    @Entry var designNewFile: (@MainActor () -> Void)?
}

struct DesignFileCommands: Commands {
    @FocusedValue(\.designNewFile) private var newFile

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            DesignFileMenu(newFile: newFile)
        }
    }
}

/// The File menu's New File item; a nil action shows it disabled.
struct DesignFileMenu: View {
    let newFile: (@MainActor () -> Void)?

    var body: some View {
        Button("New File", systemImage: "plus") { newFile?() }
            .keyboardShortcut("n", modifiers: .command)
            .disabled(newFile == nil)
    }
}
