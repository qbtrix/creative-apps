// PhotoCommands+Layer.swift: Photo's Layer menu: New, Delete, Rename…,
// Show/Hide, Bring Forward, Send Backward, Select Layer Above and Below. The
// items are a view, PhotoLayerMenu, so the snapshot tests can draw them.
import PhotoModel
import SwiftUI

extension PhotoCommands {
    var layerMenu: some Commands {
        CommandMenu("Layer") {
            PhotoLayerMenu(menu: menu)
        }
    }
}

/// The Layer menu's items, a view so the snapshot tests can draw them.
struct PhotoLayerMenu: View {
    let menu: PhotoMenu

    var body: some View {
        Button("New Layer", systemImage: "plus") { menu.perform(.addLayer) }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(!menu.hasImage)
        Button("Delete Layer", systemImage: "trash") { menu.perform(.deleteLayer) }
            .disabled(!menu.canDeleteLayer)
        Divider()
        Button("Rename Layer…", systemImage: "pencil") { menu.perform(.renameLayer) }
            .disabled(!menu.canEditLayer)
        Button(menu.visibilityTitle, systemImage: menu.visibilityTitle == "Show Layer" ? "eye" : "eye.slash") {
            if let selected = menu.selectedLayer { menu.perform(.toggleVisibility(selected)) }
        }
        .disabled(!menu.canEditLayer)
        Divider()
        Button("Bring Forward", systemImage: "square.2.layers.3d.top.filled") { menu.perform(.bringForward) }
            .keyboardShortcut("]")
            .disabled(!menu.canBringForward)
        Button("Send Backward", systemImage: "square.2.layers.3d.bottom.filled") { menu.perform(.sendBackward) }
            .keyboardShortcut("[")
            .disabled(!menu.canSendBackward)
        Button("Select Layer Above", systemImage: "arrow.up") { menu.perform(.selectLayerAbove) }
            .keyboardShortcut("]", modifiers: [.command, .option])
            .disabled(!menu.canBringForward)
        Button("Select Layer Below", systemImage: "arrow.down") { menu.perform(.selectLayerBelow) }
            .keyboardShortcut("[", modifiers: [.command, .option])
            .disabled(!menu.canSendBackward)
    }
}
