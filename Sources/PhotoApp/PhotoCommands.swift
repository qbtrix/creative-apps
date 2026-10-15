// PhotoCommands.swift: Photo's menu bar, composed in order from one file per
// menu (PhotoCommands+File, +Edit, +Select, +Image, +Layer, +View). File: New
// Image, Open…, Save, Save As…, Export…; Edit: Undo and Redo named for the
// edit, Delete Selection, Fill Selection; Select: All, Deselect; Image: Image
// Size…, Rotate, Straighten…; Layer: New, Delete, Rename…, Show/Hide, Bring
// Forward, Send Backward, Select Layer Above and Below; View: Zoom In, Zoom
// Out, Actual Size, Fit on Screen. The focused window publishes a PhotoMenu
// (what can run now, and where to send it) as a focused scene value; an item
// that can't run is disabled, never hidden. Select > All owns Command-A, so while a text field is being edited
// (a sheet's, the rename alert's, an inspector number) it selects that field's
// text instead, and it never selects the canvas while a sheet or alert is up
// (#575). A disabled item would swallow the key, so it is disabled only for a
// focused window with no image. Every top bar command is here too.
import AppKit
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

    /// Command-A: all of the focused text field's text while one is being
    /// edited, else the canvas when it can be selected.
    @MainActor func selectAll() {
        if (NSApp.keyWindow?.firstResponder as? NSTextView)?.isEditable == true {
            _ = NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
        } else if canSelectAll {
            perform(.selectAll)
        }
    }

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

/// Composes the menus; each menu's items live in PhotoCommands+<Menu>.swift.
struct PhotoCommands: Commands {
    @FocusedValue(\.photoMenu) var focused

    var menu: PhotoMenu { focused ?? PhotoMenu() }

    var body: some Commands {
        fileMenu
        editMenu
        selectMenu
        imageMenu
        layerMenu
        viewMenu
    }
}
