// PhotoCommands.swift: Photo's menu bar. File: New Image, Open…, Save, Save
// As…, Export…; Edit: Undo and Redo named for the edit, Delete Selection, Fill
// Selection; Select: All, Deselect; Image: Image Size…, Rotate, Straighten…;
// Layer: New, Delete, Rename…, Show/Hide, Bring Forward, Send Backward, Select
// Layer Above and Below; View: Zoom In, Zoom Out, Actual Size, Fit on Screen.
// The focused window publishes a PhotoMenu (what can run now, and where to
// send it) as a focused scene value; an item that can't run is disabled, never
// hidden. Select > All is disabled while a sheet or the rename alert is up, so
// Command-A reaches the focused text field and selects its text (#575). Every
// top bar command is here too.
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
    /// A layer sits above the selected one (Bring Forward, Select Layer Above).
    var canBringForward = false
    /// A layer sits below the selected one (Send Backward, Select Layer Below).
    var canSendBackward = false
    var selectedLayer: PhotoLayer.ID?
    /// A sheet or alert covers the canvas; its text fields own Command-A.
    var isPresenting = false

    /// Select > All acts on the canvas, so not while a sheet is up.
    var canSelectAll: Bool { hasImage && !isPresenting }

    init() {}

    init(model: PhotoWorkspace, isPresenting: Bool = false, perform: @escaping PhotoPerform) {
        self.perform = perform
        self.isPresenting = isPresenting
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
        canBringForward = model.canBringSelectedLayerForward
        canSendBackward = model.canSendSelectedLayerBackward
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
            Button("Save As…") { menu.perform(.saveAs) }.keyboardShortcut("s", modifiers: [.command, .shift])
                .disabled(!menu.hasImage)
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
            Button("All") { menu.perform(.selectAll) }.keyboardShortcut("a").disabled(!menu.canSelectAll)
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
            Button("Actual Size") { menu.perform(.actualSize) }.keyboardShortcut("1").disabled(!menu.hasImage)
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
