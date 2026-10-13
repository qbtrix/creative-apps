// PhotoCommands.swift: Photo's menu bar. File: New Image, Open…, Save,
// Export…; Edit: Undo and Redo named for the edit, Delete Selection, Fill
// Selection; Select: All, Deselect; Image: Image Size… and Rotate; Layer:
// New, Delete, Rename…, Show/Hide; View: Zoom In, Zoom Out, Fit on Screen.
// The focused window publishes a PhotoMenu (what can run now, and where to
// send it) as a focused scene value; an item that can't run is disabled, never
// hidden. Every top bar command is here too.
import PhotoModel
import SwiftUI

/// What the focused Photo window's menus can do now.
struct PhotoMenu {
    var perform: PhotoPerform = { _ in }
    var hasImage = false
    var canUndo = false
    var canRedo = false
    var undoTitle = "Undo"
    var redoTitle = "Redo"
    var canDeselect = false
    var canEditSelection = false
    var canDeleteLayer = false
    var canEditLayer = false
    var visibilityTitle = "Hide Layer"
    var selectedLayer: PhotoLayer.ID?

    init() {}

    init(model: PhotoWorkspace, perform: @escaping PhotoPerform) {
        self.perform = perform
        hasImage = model.canvas != nil
        canUndo = model.canUndo
        canRedo = model.canRedo
        undoTitle = model.undoActionName
        redoTitle = model.redoActionName
        canDeselect = model.canDeselect
        canEditSelection = model.canEditSelection
        canDeleteLayer = model.canDeleteSelectedLayer
        canEditLayer = model.canEditSelectedLayer
        visibilityTitle = model.visibilityCommandTitle
        selectedLayer = model.selectedLayerID
    }
}

extension FocusedValues {
    /// The focused Photo window's menu; nil with no Photo window focused.
    var photoMenu: PhotoMenu? {
        get { self[PhotoMenuKey.self] }
        set { self[PhotoMenuKey.self] = newValue }
    }
}

/// A plain key rather than `@Entry`, so PhotoApp builds without the SwiftUI
/// macro plugin (Command Line Tools).
private struct PhotoMenuKey: FocusedValueKey {
    typealias Value = PhotoMenu
}

struct PhotoCommands: Commands {
    @FocusedValue(\.photoMenu) private var focused

    private var menu: PhotoMenu { focused ?? PhotoMenu() }

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Image") { menu.perform(.newImage) }.keyboardShortcut("n")
            Button("Open…") { menu.perform(.open) }.keyboardShortcut("o")
        }
        CommandGroup(replacing: .saveItem) {
            Button("Save") { menu.perform(.save) }.keyboardShortcut("s").disabled(!menu.hasImage)
            Button("Export…") { menu.perform(.export) }.keyboardShortcut("e", modifiers: [.command, .shift])
                .disabled(!menu.hasImage)
        }
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
        CommandMenu("Select") {
            Button("All") { menu.perform(.selectAll) }.keyboardShortcut("a").disabled(!menu.hasImage)
            Button("Deselect") { menu.perform(.deselect) }.keyboardShortcut("d").disabled(!menu.canDeselect)
        }
        CommandMenu("Image") {
            PhotoImageMenu(perform: menu.perform).disabled(!menu.hasImage)
        }
        CommandMenu("Layer") {
            PhotoLayerMenu(menu: menu)
        }
        CommandGroup(after: .toolbar) {
            Button("Zoom In") { menu.perform(.zoomIn) }.keyboardShortcut("=").disabled(!menu.hasImage)
            Button("Zoom Out") { menu.perform(.zoomOut) }.keyboardShortcut("-").disabled(!menu.hasImage)
            Button("Fit on Screen") { menu.perform(.fit) }.keyboardShortcut("0").disabled(!menu.hasImage)
            Divider()
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
    }
}
