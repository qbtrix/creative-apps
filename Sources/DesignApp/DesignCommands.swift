// DesignCommands.swift: Design's menu bar. File: New File, Open…, Save, Save As…;
// Edit: Undo and Redo named for the edit, Delete Layer; Page: Add Page, Delete
// Page; View: Zoom In, Zoom Out, Fit Page. Every top bar command is here too.
//
// The focused window publishes a DesignMenu (what can run now, and where to send
// it) as a focused scene value. An item that can't run is disabled, never hidden.
// With no Design window focused only New File acts: it opens a window that starts
// with a new file. Edit > Undo and Redo replace the system pair so they run the
// model's history; that costs the system's own Undo inside a text field. The stock
// pasteboard group stays, so Select All still works there. Delete Layer has no
// shortcut: the canvas handles the Delete key.
import DesignModel
import SwiftUI

/// What the focused Design window's menus and top bar can do now.
struct DesignMenu {
    var perform: DesignPerform = { _ in }
    /// Whether a Design window is focused; Open needs one to open into.
    var hasWindow = false
    var isOpen = false
    var undoTitle = "Undo"
    var redoTitle = "Redo"
    /// Why Undo or Redo can't run now; nil when it can.
    var undoHelp: String? = "Nothing to undo."
    var redoHelp: String? = "Nothing to redo."
    var canDeletePage = false
    /// A layer is selected and unlocked, the only kind Delete Layer can remove, and no text is being edited.
    var canDeleteLayer = false

    var canUndo: Bool { undoHelp == nil }
    var canRedo: Bool { redoHelp == nil }

    /// No window is focused: New File opens one through `newWindow`; the rest is disabled.
    init(newWindow: @escaping @MainActor () -> Void = {}) {
        perform = { intent in
            if case .newFile = intent { newWindow() }
        }
    }

    init(model: DesignWorkspace, perform: @escaping DesignPerform) {
        self.perform = perform
        hasWindow = true
        isOpen = model.isOpen
        undoTitle = model.undoActionName
        redoTitle = model.redoActionName
        // The model ignores both while a text node is being edited, so they say so and stay off.
        let editing = model.editingTextID != nil
        undoHelp = editing ? Self.finishEditing : model.canUndo ? nil : "Nothing to undo."
        redoHelp = editing ? Self.finishEditing : model.canRedo ? nil : "Nothing to redo."
        canDeletePage = model.canDeletePage
        canDeleteLayer = !editing && !model.hasMultipleSelection && (model.selectedNode.map { model.lockHelp($0.id) == nil } ?? false)
    }

    private static let finishEditing = "Finish editing the text first."
}

/// A plain key rather than `@Entry`, so DesignApp builds without the SwiftUI
/// macro plugin (Command Line Tools).
private struct DesignMenuKey: FocusedValueKey {
    typealias Value = DesignMenu
}

extension FocusedValues {
    /// The focused Design window's menu; nil with no Design window focused.
    var designMenu: DesignMenu? {
        get { self[DesignMenuKey.self] }
        set { self[DesignMenuKey.self] = newValue }
    }
}

struct DesignCommands: Commands {
    @FocusedValue(\.designMenu) private var focused
    @Environment(\.openWindow) private var openWindow

    private var menu: DesignMenu {
        focused
            ?? DesignMenu(newWindow: {
                openWindow(id: DesignLaunch.windowID, value: DesignLaunch(startsNewFile: true))
            })
    }

    var body: some Commands {
        CommandGroup(replacing: .newItem) { DesignFileMenu(menu: menu) }
        CommandGroup(replacing: .undoRedo) { DesignHistoryMenu(menu: menu) }
        CommandGroup(after: .pasteboard) {
            Divider()
            DesignDeleteLayerItem(menu: menu)
        }
        CommandMenu("Page") { DesignPageMenu(menu: menu) }
        CommandGroup(after: .toolbar) {
            DesignViewMenu(menu: menu)
            Divider()
        }
    }
}

/// File: New File and Open…, then Save and Save As…. The menu bar keeps its own Close below.
struct DesignFileMenu: View {
    let menu: DesignMenu

    var body: some View {
        Button("New File", systemImage: "plus") { menu.perform(.newFile) }
            .keyboardShortcut("n")
        Button("Open…", systemImage: "folder") { menu.perform(.open) }
            .keyboardShortcut("o")
            .disabled(!menu.hasWindow)
        Divider()
        Button("Save", systemImage: "square.and.arrow.down") { menu.perform(.save) }
            .keyboardShortcut("s")
            .disabled(!menu.isOpen)
        Button("Save As…") { menu.perform(.saveAs) }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(!menu.isOpen)
    }
}

/// Edit: Undo and Redo, titled for the edit they act on ("Undo Add Rectangle").
struct DesignHistoryMenu: View {
    let menu: DesignMenu

    var body: some View {
        Button(menu.undoTitle) { menu.perform(.undo) }
            .disabled(!menu.canUndo)
            .keyboardShortcut("z", modifiers: .command)
        Button(menu.redoTitle) { menu.perform(.redo) }
            .disabled(!menu.canRedo)
            .keyboardShortcut("z", modifiers: [.shift, .command])
    }
}

/// Edit: Delete Layer, which removes the selected layer; disabled with none or a locked one.
struct DesignDeleteLayerItem: View {
    let menu: DesignMenu

    var body: some View {
        Button("Delete Layer", systemImage: "trash") { menu.perform(.deleteSelection) }
            .disabled(!menu.canDeleteLayer)
    }
}

/// Page: Add Page and Delete Page (never the last one).
struct DesignPageMenu: View {
    let menu: DesignMenu

    var body: some View {
        Button("Add Page", systemImage: "doc.badge.plus") { menu.perform(.addPage) }
            .disabled(!menu.isOpen)
        Button("Delete Page", systemImage: "trash") { menu.perform(.deletePage) }
            .disabled(!menu.canDeletePage)
    }
}

/// View: Zoom In, Zoom Out and Fit Page.
struct DesignViewMenu: View {
    let menu: DesignMenu

    var body: some View {
        Button("Zoom In") { menu.perform(.zoomIn) }
            .keyboardShortcut("=")
            .disabled(!menu.isOpen)
        Button("Zoom Out") { menu.perform(.zoomOut) }
            .keyboardShortcut("-")
            .disabled(!menu.isOpen)
        Button("Fit Page") { menu.perform(.fit) }
            .keyboardShortcut("0")
            .disabled(!menu.isOpen)
    }
}
