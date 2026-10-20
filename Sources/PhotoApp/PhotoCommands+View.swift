// PhotoCommands+View.swift: Photo's View menu items after the toolbar group:
// Zoom In, Zoom Out, Actual Size, Fit on Screen, all off with no image.
import SuiteUI
import SwiftUI

extension PhotoCommands {
    var viewMenu: some Commands {
        CommandGroup(after: .toolbar) {
            menu.item("view.zoom-in", shortcut: KeyboardShortcut("=")) { menu.perform(.zoomIn) }
            menu.item("view.zoom-out", shortcut: KeyboardShortcut("-")) { menu.perform(.zoomOut) }
            menu.item("view.actual-size", shortcut: KeyboardShortcut("1")) { menu.perform(.actualSize) }
            menu.item("view.fit", shortcut: KeyboardShortcut("0")) { menu.perform(.fit) }
            Divider()
        }
    }
}
