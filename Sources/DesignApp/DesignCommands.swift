// DesignCommands.swift: Design's menu bar. File: New File, Open…, Save, Save As…;
// Edit: Undo and Redo named for the edit, then after the stock Cut, Copy, Paste,
// Delete and Select All, Duplicate (DesignEditMenu); Page: Add Page,
// Rename Page…, Delete Page; Object: Group, Ungroup, Arrange, Align and
// Distribute (DesignObjectMenu); View: Zoom In, Zoom Out, Fit Page, Zoom to
// Selection. Every top bar command is here too. Every item Design adds carries
// its SF Symbol, the toolbar's where the toolbar has the same command.
//
// The focused window publishes a DesignMenu (what can run now, and where to send
// it) as a focused scene value. An item that can't run is disabled, never hidden,
// and its tooltip is the Model's help for it.
// With no Design window focused only New File acts: it opens a window that starts
// with a new file. Edit > Undo and Redo replace the system pair so they run the
// model's history; that costs the system's own Undo inside a text field. The stock
// pasteboard group stays, so Select All still works there. Its Delete removes the
// selected layers while the canvas or the Layers list has focus (`canDeleteLayer`).
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
    /// A layer is selected and unlocked, the only kind Delete can remove, and no text is being edited.
    var canDeleteLayer = false
    /// Why each Align command can't run, keyed by edge; an edge left out can run.
    var alignHelp = DesignWorkspace().alignHelps
    /// Why the whole Arrange or Align submenu is off; nil when one of its items can run.
    var arrangeMenuHelp = DesignWorkspace().arrangeMenuHelp
    var alignMenuHelp = DesignWorkspace().alignMenuHelp
    /// Why each selection command in `menuCommands` can't run; one left out can run.
    var commandHelp = Self.helps(DesignWorkspace())
    var zoomToSelectionHelp = DesignWorkspace().zoomToSelectionHelp
    /// Why the items that need only an open file (Add Page, the zoom items) can't run.
    var noFileHelp = DesignWorkspace().addPageHelp
    var deletePageHelp = DesignWorkspace().deletePageHelp
    /// Rename Page… has no name field of its own yet: the page row's rename is the Layers panel's.
    var renamePageHelp = Self.renamePageHelp(DesignWorkspace())
    var deleteLayerHelp: String? = DesignRefusal.nothingSelected.help

    /// The selection commands the Edit and Object menus show beside Align.
    static let menuCommands: [DesignCommand] = [.duplicate, .group, .ungroup]
        + DesignArrangeStep.allCases.map { .arrange($0) } + DesignDistributeAxis.allCases.map { .distribute($0) }

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
        canDeleteLayer = Self.deletesLayer(model)
        alignHelp = model.alignHelps
        arrangeMenuHelp = model.arrangeMenuHelp
        alignMenuHelp = model.alignMenuHelp
        commandHelp = Self.helps(model)
        zoomToSelectionHelp = model.zoomToSelectionHelp
        noFileHelp = model.addPageHelp
        deletePageHelp = model.deletePageHelp
        renamePageHelp = Self.renamePageHelp(model)
        deleteLayerHelp = model.help(.delete)
    }

    /// Why `command` can't run now; nil when it can.
    func help(_ command: DesignCommand) -> String? { commandHelp[command] }

    /// Whether Edit > Delete removes the selection now: `.delete`'s help is nil, for one layer or several (#2463).
    static func deletesLayer(_ model: DesignWorkspace) -> Bool {
        model.help(.delete) == nil
    }

    private static func helps(_ model: DesignWorkspace) -> [DesignCommand: String] {
        Dictionary(uniqueKeysWithValues: menuCommands.compactMap { command in model.help(command).map { (command, $0) } })
    }

    private static func renamePageHelp(_ model: DesignWorkspace) -> String {
        model.addPageHelp ?? DesignRefusal.notBuilt("Renaming a page from the menu").help
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
            DesignEditItems(menu: menu)
        }
        CommandMenu("Page") { DesignPageMenu(menu: menu) }
        CommandMenu("Object") { DesignObjectMenu(menu: menu) }
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
        Button("New File", systemImage: DesignToolbarItem.newFile.systemImage) { menu.perform(.newFile) }
            .keyboardShortcut("n")
        Button("Open…", systemImage: DesignToolbarItem.open.systemImage) { menu.perform(.open) }
            .keyboardShortcut("o")
            .disabled(!menu.hasWindow)
        Divider()
        Button("Save", systemImage: DesignToolbarItem.save.systemImage) { menu.perform(.save) }
            .keyboardShortcut("s")
            .disabled(!menu.isOpen)
        Button("Save As…", systemImage: "square.and.arrow.down.on.square") { menu.perform(.saveAs) }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(!menu.isOpen)
    }
}

/// Edit: Undo and Redo, titled for the edit they act on ("Undo Add Rectangle").
struct DesignHistoryMenu: View {
    let menu: DesignMenu

    var body: some View {
        Button(menu.undoTitle, systemImage: DesignToolbarItem.undo.systemImage) { menu.perform(.undo) }
            .disabled(!menu.canUndo)
            .help(menu.undoHelp ?? "")
            .keyboardShortcut("z", modifiers: .command)
        Button(menu.redoTitle, systemImage: DesignToolbarItem.redo.systemImage) { menu.perform(.redo) }
            .disabled(!menu.canRedo)
            .help(menu.redoHelp ?? "")
            .keyboardShortcut("z", modifiers: [.shift, .command])
    }
}

/// The system's Edit > Delete as the selection leaves it: on when `.delete` can run (one
/// unlocked layer or several), else off with why. The menu bar draws the real item (designPasteboardCommands hooks it);
/// this one is its stand-in where the menu bar doesn't render (DesignEditMenuSnapshots).
struct DesignDeleteLayerItem: View {
    let menu: DesignMenu

    var body: some View {
        Button("Delete", systemImage: "trash") { menu.perform(.deleteSelection) }
            .disabled(!menu.canDeleteLayer)
            .help(menu.deleteLayerHelp ?? "")
    }
}

/// Page: Add Page, Rename Page… (off until it has a name field) and Delete Page (never the last one).
struct DesignPageMenu: View {
    let menu: DesignMenu

    var body: some View {
        Button("Add Page", systemImage: "doc.badge.plus") { menu.perform(.addPage) }
            .disabled(!menu.isOpen)
            .help(menu.noFileHelp ?? "")
        // No intent until the menu has a name field to send `.renamePage` from; always disabled.
        Button("Rename Page…", systemImage: "pencil") {}
            .disabled(true)
            .help(menu.renamePageHelp)
        Button("Delete Page", systemImage: "trash") { menu.perform(.deletePage) }
            .disabled(!menu.canDeletePage)
            .help(menu.deletePageHelp ?? "")
    }
}

/// View: Zoom In, Zoom Out, Fit Page and Zoom to Selection.
struct DesignViewMenu: View {
    let menu: DesignMenu

    var body: some View {
        Button("Zoom In", systemImage: DesignToolbarItem.zoomIn.systemImage) { menu.perform(.zoomIn) }
            .keyboardShortcut("=")
            .disabled(!menu.isOpen)
            .help(menu.noFileHelp ?? "")
        Button("Zoom Out", systemImage: DesignToolbarItem.zoomOut.systemImage) { menu.perform(.zoomOut) }
            .keyboardShortcut("-")
            .disabled(!menu.isOpen)
            .help(menu.noFileHelp ?? "")
        Button("Fit Page", systemImage: DesignToolbarItem.fit.systemImage) { menu.perform(.fit) }
            .keyboardShortcut("0")
            .disabled(!menu.isOpen)
            .help(menu.noFileHelp ?? "")
        Button("Zoom to Selection", systemImage: "viewfinder") { menu.perform(.zoomToSelection) }
            .keyboardShortcut("2", modifiers: [.option, .command])
            .disabled(menu.zoomToSelectionHelp != nil)
            .help(menu.zoomToSelectionHelp ?? "")
    }
}
