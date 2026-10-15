// LibraryCommands.swift: every app item of Library's menu bar (blueprint
// 6.2), fed by the focused window's LibraryMenu. File: Import Folder… ⇧⌘I,
// Load Sample Photos, Export… ⇧⌘E (Close is the system's). Edit: Undo ⌘Z and
// Redo ⇧⌘Z in place of the system pair, Select All ⌘A and Deselect ⇧⌘A in
// place of the pasteboard group (Library has no text fields). View: Grid,
// Loupe, Zoom In ⌘+ and Zoom Out ⌘- (Larger and Smaller Thumbnails in the
// grid), Zoom to Fit ⌘0, Actual Size ⌘1, Sort By. Photo: Copy Settings ⇧⌘C,
// Paste Settings ⇧⌘V, Reset Develop, Crop, Reset Crop. Metadata: Set Rating,
// Set Flag, Set Label, Auto Advance. An item whose action is nil is disabled,
// never hidden, and its help says why. Single keys (0-5, P, X, U, R, G,
// Return) act only while the grid or loupe has focus, so their items take no
// key equivalent and name the key in their help instead ("Pick (P)").
import LibraryModel
import SwiftUI

/// One menu item: disabled while `action` is nil, with `reason` as its help.
struct LibraryMenuItem: View {
    let title: String
    var systemImage: String?
    let action: LibraryMenu.Action?
    var reason: String
    var key: String?
    var shortcut: KeyboardShortcut?

    var body: some View {
        let named = key.map { "\(title) (\($0))" } ?? title
        Button {
            action?()
        } label: {
            if let systemImage { Label(title, systemImage: systemImage) } else { Text(title) }
        }
        .keyboardShortcut(shortcut)
        .disabled(action == nil)
        .help(action == nil ? "\(named): \(reason)" : named)
    }
}

struct LibraryCommands: Commands {
    @FocusedValue(\.libraryMenu) private var focused

    private var menu: LibraryMenu { focused ?? .disabled }
    private static let noWindow = "Open the Library window first."

    /// The services' reason for `member`, else `fallback`; no window says so.
    private func why(_ member: String?, _ fallback: String) -> String {
        guard focused != nil else { return Self.noWindow }
        return member.flatMap { menu.help(for: $0) } ?? fallback
    }

    /// `perform` applied to `value`, nil (disabled) while `perform` is nil.
    private func bind<Value>(_ perform: (@MainActor (Value) -> Void)?, _ value: Value) -> LibraryMenu.Action? {
        guard let perform else { return nil }
        return { perform(value) }
    }

    var body: some Commands {
        CommandGroup(after: .newItem) {
            LibraryMenuItem(
                title: "Import Folder…", systemImage: "folder.badge.plus", action: menu.file.importFolder,
                reason: menu.file.importHelp ?? why("importer", "Import isn't available right now."),
                shortcut: KeyboardShortcut("i", modifiers: [.command, .shift]))
            LibraryMenuItem(
                title: "Load Sample Photos", systemImage: "photo.badge.plus", action: menu.edit.loadSamples,
                reason: why(nil, "Samples can't load right now."))
            LibraryMenuItem(
                title: "Export…", systemImage: "square.and.arrow.up", action: menu.export.export,
                reason: menu.export.exportHelp ?? why("exporter", "Select photos to export."),
                shortcut: KeyboardShortcut("e", modifiers: [.command, .shift]))
        }
        CommandGroup(replacing: .undoRedo) {
            LibraryMenuItem(
                title: menu.edit.undoTitle, action: menu.edit.undo, reason: why(nil, "There is nothing to undo."),
                shortcut: KeyboardShortcut("z"))
            LibraryMenuItem(
                title: menu.edit.redoTitle, action: menu.edit.redo, reason: why(nil, "There is nothing to redo."),
                shortcut: KeyboardShortcut("z", modifiers: [.command, .shift]))
        }
        CommandGroup(replacing: .pasteboard) {
            LibraryMenuItem(
                title: "Select All", action: menu.edit.selectAll, reason: why(nil, "There are no photos to select."),
                shortcut: KeyboardShortcut("a"))
            LibraryMenuItem(
                title: "Deselect", action: menu.edit.deselect, reason: why(nil, "No photos are selected."),
                shortcut: KeyboardShortcut("a", modifiers: [.command, .shift]))
        }
        CommandGroup(before: .toolbar) { viewItems }
        CommandMenu("Photo") { photoItems }
        CommandMenu("Metadata") { metadataItems }
    }

    @ViewBuilder private var viewItems: some View {
        let view = menu.view
        LibraryMenuItem(
            title: "Grid", systemImage: "square.grid.2x2", action: view.grid,
            reason: why(nil, "The grid is already showing."), key: "G")
        LibraryMenuItem(
            title: "Loupe", systemImage: "rectangle", action: view.loupe,
            reason: why(nil, "The loupe is already showing, or there are no photos."), key: "Return")
        Divider()
        LibraryMenuItem(
            title: view.zoomInTitle, systemImage: "plus.magnifyingglass", action: view.zoomIn,
            reason: why(nil, "Can't zoom in further."), shortcut: KeyboardShortcut("+"))
        LibraryMenuItem(
            title: view.zoomOutTitle, systemImage: "minus.magnifyingglass", action: view.zoomOut,
            reason: why(nil, "Can't zoom out further."), shortcut: KeyboardShortcut("-"))
        LibraryMenuItem(
            title: "Zoom to Fit", action: view.zoomToFit, reason: why("loupe", "Open a photo in the loupe first."),
            shortcut: KeyboardShortcut("0"))
        LibraryMenuItem(
            title: "Actual Size", action: view.actualSize, reason: why("loupe", "Open a photo in the loupe first."),
            shortcut: KeyboardShortcut("1"))
        Divider()
        Picker("Sort By", selection: Binding(get: { menu.view.sort }, set: { menu.view.setSort?($0) })) {
            ForEach(LibrarySort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
        }
        .disabled(view.setSort == nil)
        .help(view.setSort == nil ? "Sort By: \(why(nil, "There are no photos to sort."))" : "Sort By")
        Divider()
    }

    @ViewBuilder private var photoItems: some View {
        let photo = menu.photo
        let develop = why("develop", "Select a photo to develop.")
        let crop = why("crop", "Select one photo to crop.")
        LibraryMenuItem(
            title: "Copy Settings", action: photo.copySettings, reason: develop,
            shortcut: KeyboardShortcut("c", modifiers: [.command, .shift]))
        LibraryMenuItem(
            title: "Paste Settings", action: photo.pasteSettings, reason: develop,
            shortcut: KeyboardShortcut("v", modifiers: [.command, .shift]))
        LibraryMenuItem(title: "Reset Develop", action: photo.resetDevelop, reason: develop)
        Divider()
        LibraryMenuItem(title: photo.cropTitle, systemImage: "crop", action: photo.toggleCrop, reason: crop, key: "R")
        LibraryMenuItem(title: "Reset Crop", action: photo.resetCrop, reason: crop)
    }

    @ViewBuilder private var metadataItems: some View {
        let cull = menu.cull
        let reason = why("culling", "Select photos first.")
        Menu("Set Rating") {
            ForEach(0...5, id: \.self) { stars in
                LibraryMenuItem(
                    title: stars == 0 ? "No Stars" : stars == 1 ? "1 Star" : "\(stars) Stars",
                    action: bind(cull.setRating, stars), reason: reason, key: "\(stars)")
            }
        }
        Menu("Set Flag") {
            LibraryMenuItem(title: "Pick", action: bind(cull.setFlag, .pick), reason: reason, key: "P")
            LibraryMenuItem(title: "Reject", action: bind(cull.setFlag, .reject), reason: reason, key: "X")
            LibraryMenuItem(title: "Clear Flag", action: bind(cull.setFlag, PhotoFlag.none), reason: reason, key: "U")
        }
        Menu("Set Label") {
            LibraryMenuItem(title: "None", action: bind(cull.setLabel, nil), reason: reason)
            ForEach(PhotoLabel.allCases, id: \.self) { label in
                LibraryMenuItem(title: label.rawValue, action: bind(cull.setLabel, label), reason: reason)
            }
        }
        Divider()
        let advance = why("culling", "Auto Advance isn't available yet.")
        Toggle(
            "Auto Advance",
            isOn: Binding(get: { menu.cull.autoAdvance }, set: { _ in menu.cull.toggleAutoAdvance?() })
        )
        .disabled(cull.toggleAutoAdvance == nil)
        .help(cull.toggleAutoAdvance == nil ? "Auto Advance: \(advance)" : "Auto Advance")
    }
}
