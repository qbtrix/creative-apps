// PhotoCommands.swift: Photo's Layer menu in the menu bar: New Layer,
// Delete Layer, Rename Layer… and Show/Hide Layer for the focused window's
// selected layer. The window publishes its actions as a focused scene value,
// each nil while it can't run (PhotoWorkspace's canAddLayer,
// canDeleteSelectedLayer, canEditSelectedLayer), so the items disable rather
// than hide. New Layer is Shift-Command-N; nothing else in Photo uses it.
import SwiftUI

/// The focused window's layer actions; nil for one that can't run now.
struct PhotoLayerActions {
    var newLayer: (@MainActor () -> Void)?
    var deleteLayer: (@MainActor () -> Void)?
    var renameLayer: (@MainActor () -> Void)?
    var toggleVisibility: (@MainActor () -> Void)?
    /// "Hide Layer" or "Show Layer", saying what the toggle will do.
    var visibilityTitle = "Hide Layer"
}

extension FocusedValues {
    /// The focused Photo window's layer actions; nil with no Photo window focused.
    @Entry var photoLayerActions: PhotoLayerActions?
}

struct PhotoCommands: Commands {
    @FocusedValue(\.photoLayerActions) private var actions

    var body: some Commands {
        CommandMenu("Layer") {
            PhotoLayerMenu(actions: actions ?? PhotoLayerActions())
        }
    }
}

/// The Layer menu's items, a view so the snapshot tests can draw them.
struct PhotoLayerMenu: View {
    let actions: PhotoLayerActions

    var body: some View {
        Button("New Layer", systemImage: "plus") { actions.newLayer?() }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(actions.newLayer == nil)
        Button("Delete Layer", systemImage: "trash") { actions.deleteLayer?() }
            .disabled(actions.deleteLayer == nil)
        Divider()
        Button("Rename Layer…", systemImage: "pencil") { actions.renameLayer?() }
            .disabled(actions.renameLayer == nil)
        Button(actions.visibilityTitle, systemImage: actions.visibilityTitle == "Show Layer" ? "eye" : "eye.slash") {
            actions.toggleVisibility?()
        }
        .disabled(actions.toggleVisibility == nil)
    }
}
