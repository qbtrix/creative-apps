// PhotoCommands+View.swift: Photo's View menu items after the toolbar group:
// Zoom In, Zoom Out, Actual Size, Fit on Screen, all off with no image; and
// Window > History (history-panel PH-2) above the window size items, which
// shows the inspector's History tab, off with no image.
import SuiteUI
import SwiftUI

extension PhotoCommands {
    @CommandsBuilder var viewMenu: some Commands {
        CommandGroup(after: .toolbar) {
            menu.item("view.zoom-in", shortcut: KeyboardShortcut("=")) { menu.perform(.zoomIn) }
            menu.item("view.zoom-out", shortcut: KeyboardShortcut("-")) { menu.perform(.zoomOut) }
            menu.item("view.actual-size", shortcut: KeyboardShortcut("1")) { menu.perform(.actualSize) }
            menu.item("view.fit", shortcut: KeyboardShortcut("0")) { menu.perform(.fit) }
            Divider()
        }
        CommandGroup(before: .windowSize) {
            MenuCommand("History", help: historyHelp, isEnabled: menu.hasImage) {
                menu.perform(.history(.showTab(.history)))
            }
            Divider()
        }
    }

    /// Window > History's help: what it does, or why it can't.
    var historyHelp: String {
        menu.hasImage ? "Shows the image's steps in the inspector." : "Open an image first."
    }
}
