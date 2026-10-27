// DesignCommands.swift: Design's menu bar. File: New File, Open…, Close, Save, Save As…,
// Export… ⇧⌘E (the export sheet, DesignExportArea), Place… ⇧⌘P (SuiteUI's PlacePanel; each file it reads
// becomes a picture, placed-images PD-u);
// Edit: Undo and Redo named for the edit, then after the stock Cut, Copy, Paste,
// Delete and Select All, Duplicate (DesignEditMenu); Page: Add Page,
// Rename Page…, Delete Page; Object: Group, Ungroup, Arrange, Align and
// Distribute (DesignObjectMenu); View: Zoom In, Zoom Out, Fit Page, Snap to
// Layers (a checked preference in user defaults, DesignSnapToLayersItem), Zoom to Selection, Show History
// (the trailing History panel, DesignHistoryArea; Hide History while it shows). Every top bar command is here too. Every item Design adds carries
// its SF Symbol, the toolbar's where the toolbar has the same command.
//
// The focused window publishes a DesignMenu (what can run now, and where to send
// it) as a focused scene value. Each item is built from its catalog spec over DesignMenuState
// (`menu.item`, AC-d3): one that can't run is disabled, never hidden, and its tooltip says why.
// With no Design window focused only New File acts: it opens a window that starts
// with a new file. With one, New File opens SuiteUI's New Document sheet on Design's
// frame presets (DesignNewDocumentSheet, document-setup DS-10) and its Create makes the file. Edit > Undo and Redo replace the system pair. They go where the
// Model's `undoTarget(textFieldFocused:)` says: while a text field has keyboard focus,
// to the field's own undo (undo: and redo: down the responder chain, titled "Undo
// Typing" from its undo manager; DesignFieldUndo watches the key window's focus),
// else to the model's history (#275). Close (Command-W) replaces the system's in
// `.saveItem`; it sends performClose: to the key window, so an edited window asks
// first (SuiteUI's unsaved guard). The stock pasteboard group stays, so Select All still works there. Its Delete removes the
// selected layers while the canvas or the Layers list has focus (`canDeleteLayer`).
import AppKit
import DesignModel
import SuiteKernel
import SuiteUI
import SwiftUI

/// What the focused Design window's menus and top bar can do now.
struct DesignMenu {
    var perform: DesignPerform = { _ in }
    /// The focused window's workspace, which the items' catalog specs read (DesignMenuState); a blank one with no window.
    var workspace = DesignWorkspace()
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
    /// Where Edit > Undo and Redo go, given whether a text field has keyboard focus: the Model's answer.
    var undoTarget: (Bool) -> DesignUndoTarget = { DesignWorkspace().undoTarget(textFieldFocused: $0) }

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
        workspace = model
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
        undoTarget = { [model] in model.undoTarget(textFieldFocused: $0) }
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
    @FocusedValue(\.designHistoryPanel) private var historyPanel
    @Environment(\.openWindow) private var openWindow

    private var menu: DesignMenu {
        focused
            ?? DesignMenu(newWindow: {
                openWindow(id: DesignLaunch.windowID, value: DesignLaunch(startsNewFile: true))
            })
    }

    var body: some Commands {
        CommandGroup(replacing: .newItem) { DesignFileMenu(menu: menu) }
        // `.saveItem` holds the system's Close, which DesignFileMenu's own Close replaces.
        CommandGroup(replacing: .saveItem) {}
        CommandGroup(replacing: .undoRedo) { DesignHistoryMenu(menu: menu, field: DesignFieldUndo.shared.state) }
        CommandGroup(after: .pasteboard) {
            Divider()
            DesignEditItems(menu: menu)
        }
        CommandMenu("Page") { DesignPageMenu(menu: menu) }
        CommandMenu("Object") { DesignObjectMenu(menu: menu) }
        CommandGroup(after: .toolbar) {
            DesignViewMenu(menu: menu)
            DesignShowHistoryItem(panel: historyPanel)
            Divider()
        }
    }
}

/// File: New File and Open…, then Close, Save, Save As…, Export… and Place….
struct DesignFileMenu: View {
    let menu: DesignMenu

    var body: some View {
        menu.item("file.new", systemImage: DesignToolbarItem.newFile.systemImage, shortcut: KeyboardShortcut("n")) {
            if menu.hasWindow, let window = NSApp.keyWindow { DesignNewDocumentSheet.begin(on: window, perform: menu.perform) } else { menu.perform(.newFile) }
        }
        menu.item("file.open", systemImage: DesignToolbarItem.open.systemImage, shortcut: KeyboardShortcut("o")) {
            menu.perform(.open)
        }
        Divider()
        Button("Close", systemImage: "xmark") { NSApp.sendAction(#selector(NSWindow.performClose(_:)), to: nil, from: nil) }
            .keyboardShortcut("w")
        menu.item("file.save", systemImage: DesignToolbarItem.save.systemImage, shortcut: KeyboardShortcut("s")) {
            menu.perform(.save)
        }
        menu.item("file.save-as", systemImage: "square.and.arrow.down.on.square", shortcut: KeyboardShortcut("s", modifiers: [.command, .shift])) {
            menu.perform(.saveAs)
        }
        menu.item("file.export", systemImage: "square.and.arrow.up", shortcut: KeyboardShortcut("e", modifiers: [.command, .shift])) {
            menu.perform(.export)
        }
        menu.item("place.image", title: "Place…", systemImage: "photo.badge.plus", shortcut: KeyboardShortcut("p", modifiers: [.command, .shift])) {
            menu.perform(.placeFile(fill: nil))
        }
    }
}

/// File > New's sheet on the key window: Design's presets; Create runs New File (and its unsaved guard),
/// then gives the new page the setup's size and background inside that step (`shapeNewFile`).
@MainActor enum DesignNewDocumentSheet {
    static func begin(on window: NSWindow, perform: @escaping DesignPerform) {
        var panel: NSWindow?
        let sheet = NewDocumentSheet(.new(presets: DesignWorkspace.newDocumentPresets, clipboard: nil),
                                     setup: DesignWorkspace.newDocumentSetup, limits: DesignWorkspace.newDocumentLimits,
                                     onDone: { setup, _ in
                                         if let panel { window.endSheet(panel) }
                                         Task { await create(setup, on: window, perform: perform) }
                                     },
                                     onCancel: { if let panel { window.endSheet(panel) } })
        let made = NSWindow(contentViewController: NSHostingController(rootView: sheet))
        panel = made
        window.beginSheet(made)
    }

    /// New File, then, once its unsaved guard (an alert on `window`) has gone, the setup on the file it made;
    /// a guard the person cancelled leaves their file, which `shapeNewFile` refuses to reshape.
    /// The window is the live front's (`DesignShell.front`), which reads its file and adopts the shaped one.
    private static func create(_ setup: DocumentSetup, on window: NSWindow, perform: @escaping DesignPerform) async {
        guard let id = DesignShell.front.window else { return }
        perform(.newFile)
        try? await Task.sleep(for: .milliseconds(200))
        while window.attachedSheet != nil { try? await Task.sleep(for: .milliseconds(100)) }
        guard DesignShell.front.window == id, let next = DesignShell.front.document()?.shapingNewFile(setup) else { return }
        DesignShell.front.apply(next)
    }
}

/// Edit: Undo and Redo, titled for the edit they act on ("Undo Add Rectangle"), or for the
/// focused text field's typing ("Undo Typing") when `menu.undoTarget` sends them there.
struct DesignHistoryMenu: View {
    let menu: DesignMenu
    var field = DesignFieldUndo.State()

    private var inField: Bool { menu.undoTarget(field.focused) == .field }
    /// The items' state: the field's own undo while Undo and Redo go there, else the file's history.
    private var state: DesignMenuState {
        menu.state(field: inField ? DesignMenuState.FieldUndo(canUndo: field.canUndo, canRedo: field.canRedo) : nil)
    }

    var body: some View {
        menu.item(
            "edit.undo", title: inField ? field.undoTitle : menu.undoTitle, systemImage: DesignToolbarItem.undo.systemImage,
            shortcut: KeyboardShortcut("z", modifiers: .command), in: state
        ) {
            if inField { DesignFieldUndo.send("undo:") } else { menu.perform(.undo) }
        }
        menu.item(
            "edit.redo", title: inField ? field.redoTitle : menu.redoTitle, systemImage: DesignToolbarItem.redo.systemImage,
            shortcut: KeyboardShortcut("z", modifiers: [.shift, .command]), in: state
        ) {
            if inField { DesignFieldUndo.send("redo:") } else { menu.perform(.redo) }
        }
    }
}

/// The key window's focused text field and its own undo, for Edit > Undo and Redo (#275).
/// It rereads the key window's first responder after each window update and writes
/// `state` only when that changed, so the menu bar rebuilds on a focus or undo change only.
@MainActor @Observable final class DesignFieldUndo {
    struct State: Equatable {
        var focused = false
        var undoTitle = "Undo", redoTitle = "Redo"
        var canUndo = false, canRedo = false

        var undoHelp: String? { canUndo ? nil : "Nothing to undo." }
        var redoHelp: String? { canRedo ? nil : "Nothing to redo." }
    }

    static let shared = DesignFieldUndo()
    private(set) var state = State()

    private init() {
        _ = NotificationCenter.default.addObserver(forName: NSWindow.didUpdateNotification, object: nil, queue: .main) { _ in
            MainActor.assumeIsolated { DesignFieldUndo.shared.refresh() }
        }
    }

    /// Sends `action` (undo: or redo:) down the key window's responder chain, to the focused field.
    static func send(_ action: String) {
        NSApp.sendAction(Selector(action), to: nil, from: nil)
    }

    private func refresh() {
        var next = State()
        if let text = NSApp.keyWindow?.firstResponder as? NSTextView, text.isEditable {
            let undo = text.undoManager
            next = State(
                focused: true, undoTitle: undo?.undoMenuItemTitle ?? "Undo", redoTitle: undo?.redoMenuItemTitle ?? "Redo",
                canUndo: undo?.canUndo ?? false, canRedo: undo?.canRedo ?? false)
        }
        if next != state { state = next }
    }
}

/// The system's Edit > Delete as the selection leaves it: on when `.delete` can run (one
/// unlocked layer or several), else off with why. The menu bar draws the real item (designPasteboardCommands hooks it);
/// this one is its stand-in where the menu bar doesn't render (DesignEditMenuSnapshots).
struct DesignDeleteLayerItem: View {
    let menu: DesignMenu

    var body: some View {
        menu.item("edit.delete", systemImage: "trash") { menu.perform(.deleteSelection) }
    }
}

/// Page: Add Page, Rename Page… (off until it has a name field) and Delete Page (never the last one).
struct DesignPageMenu: View {
    let menu: DesignMenu

    var body: some View {
        menu.item("page.add", systemImage: "doc.badge.plus") { menu.perform(.addPage) }
        // No intent until the menu has a name field to send `.renamePage` from; its spec keeps it off (DesignMenuState).
        menu.item("page.rename", title: "Rename Page…", systemImage: "pencil") {}
        menu.item("page.delete", systemImage: "trash") { menu.perform(.deletePage) }
    }
}

/// View: Zoom In, Zoom Out, Fit Page, Snap to Layers and Zoom to Selection.
struct DesignViewMenu: View {
    let menu: DesignMenu
    /// Where Snap to Layers is stored; a test passes its own suite.
    var snapStore: UserDefaults = .standard

    var body: some View {
        menu.item("view.zoom-in", systemImage: DesignToolbarItem.zoomIn.systemImage, shortcut: KeyboardShortcut("=")) {
            menu.perform(.zoomIn)
        }
        menu.item("view.zoom-out", systemImage: DesignToolbarItem.zoomOut.systemImage, shortcut: KeyboardShortcut("-")) {
            menu.perform(.zoomOut)
        }
        menu.item("view.fit", systemImage: DesignToolbarItem.fit.systemImage, shortcut: KeyboardShortcut("0")) {
            menu.perform(.fit)
        }
        DesignSnapToLayersItem(store: snapStore)
        menu.item("view.zoom-to-selection", systemImage: "viewfinder", shortcut: KeyboardShortcut("2", modifiers: [.option, .command])) {
            menu.perform(.zoomToSelection)
        }
    }
}

/// View > Show History: shows or hides the focused window's History panel (DesignHistoryArea).
/// With no Design window focused there is no panel to show, so it is off and says why.
struct DesignShowHistoryItem: View {
    let panel: DesignHistoryShown?

    var body: some View {
        MenuCommand(DesignMenuState.spec("view.history"), on: DesignMenuState(hasWindow: panel != nil),
                    title: panel?.isShown == true ? "Hide History" : nil, systemImage: "clock.arrow.circlepath") { panel?.toggle() }
    }
}

/// View > Snap to Layers (snapping SN-8): a checked item, on by default, with no key equivalent,
/// stored under `DesignSnapSettings.defaultsKey` so it holds across relaunches. A preference, so it
/// acts with no file open; `DesignModifiers.current` reads it on every canvas step.
struct DesignSnapToLayersItem: View {
    @AppStorage private var snapsToLayers: Bool

    init(store: UserDefaults = .standard) {
        _snapsToLayers = AppStorage(wrappedValue: true, DesignSnapSettings.defaultsKey, store: store)
    }

    var body: some View {
        Toggle("Snap to Layers", systemImage: "align.horizontal.left", isOn: $snapsToLayers)
            .help("Line up a drag with the layers and the page. Hold Command to drag without snapping.")
    }

    /// Turns Snap to Layers on or off, as a click on the item does.
    func set(_ on: Bool) { snapsToLayers = on }
}
