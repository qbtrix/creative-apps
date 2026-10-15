// PhotoCommands+Layer.swift: Photo's Layer menu: New, Delete; Duplicate Layer
// (Command-J), Merge Down (Command-E) and Flatten Image (no shortcut), each
// disabled with the workspace's reason as its help when it can't run;
// Rename…, Show/Hide, Bring Forward, Send Backward, Select Layer Above and
// Below. The items are a view, PhotoLayerMenu, so the snapshot tests can draw
// them; the three new items' shortcuts and symbols are tables the tests read.
import AppKit
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
        item("Duplicate Layer", .duplicateLayer)
        item("Merge Down", .mergeDown)
        item("Flatten Image", .flattenImage)
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

    /// Command-J and Command-E; Flatten Image has none (QB-F4).
    static func shortcut(_ intent: EditIntent) -> KeyboardShortcut? {
        switch intent {
        case .duplicateLayer: KeyboardShortcut("j")
        case .mergeDown: KeyboardShortcut("e")
        case .cut, .copy, .paste, .flattenImage: nil
        }
    }

    /// The three layer commands' symbols. Merge Down's reads as two layers
    /// becoming one, not as a save (the square.and.arrow family).
    static func systemImage(_ intent: EditIntent) -> String {
        switch intent {
        case .duplicateLayer: "plus.square.on.square"
        case .mergeDown: "rectangle.compress.vertical"
        case .flattenImage: "square.stack.3d.down.right"
        case .cut: PhotoEditItem.cut.systemImage
        case .copy: PhotoEditItem.copy.systemImage
        case .paste: PhotoEditItem.paste.systemImage
        }
    }

    /// A layer command, disabled with its reason as its help when it can't run.
    private func item(_ title: String, _ intent: EditIntent) -> some View {
        let help = menu.editHelp(intent, pasteboard: PhotoPasteboardState())
        return Button(title, systemImage: Self.systemImage(intent)) { menu.perform(.edit(intent)) }
            .keyboardShortcut(Self.shortcut(intent))
            .disabled(help != nil)
            .help(help.map { "\(title): \($0)" } ?? title)
    }
}

/// The layer commands as selectors, only so `PhotoMenu.textAction` covers
/// every edit; nothing implements them, as the Layer menu sends these to the
/// window directly.
@objc protocol PhotoLayerActions {
    func duplicateLayer(_ sender: Any?)
    func mergeDown(_ sender: Any?)
    func flattenImage(_ sender: Any?)
}
