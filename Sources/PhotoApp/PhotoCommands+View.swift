// PhotoCommands+View.swift: Photo's View menu items after the toolbar group:
// Zoom In, Zoom Out, Actual Size, Fit on Screen, all off with no image.
import SwiftUI

extension PhotoCommands {
    var viewMenu: some Commands {
        CommandGroup(after: .toolbar) {
            Button("Zoom In") { menu.perform(.zoomIn) }.keyboardShortcut("=").disabled(!menu.hasImage)
            Button("Zoom Out") { menu.perform(.zoomOut) }.keyboardShortcut("-").disabled(!menu.hasImage)
            Button("Actual Size") { menu.perform(.actualSize) }.keyboardShortcut("1").disabled(!menu.hasImage)
            Button("Fit on Screen") { menu.perform(.fit) }.keyboardShortcut("0").disabled(!menu.hasImage)
            Divider()
        }
    }
}
