// LibraryCommands.swift: every app item of Library's menu bar (blueprint
// 6.2), fed by the focused window's LibraryMenu. File: Import Folder… ⇧⌘I,
// Load Sample Photos, Export… ⇧⌘E (Close is the system's). Edit: Undo ⌘Z and
// Redo ⇧⌘Z in place of the system pair, Select All ⌘A and Deselect ⇧⌘A in
// place of the pasteboard group (Library has no text fields). View: Grid,
// Loupe, Zoom In ⌘+ and Zoom Out ⌘- (Larger and Smaller Thumbnails in the
// grid), Zoom to Fit ⌘0, Actual Size ⌘1, Sort By. Photo: Copy Settings ⇧⌘C,
// Paste Settings ⇧⌘V, Reset Develop, Crop, Reset Crop. Metadata: Set Rating,
// Set Flag, Set Label, Auto Advance (its help says it moves the loupe to the
// next photo after a rating or a flag). An item whose action is nil is disabled,
// never hidden, and its help says why. Single keys (R, G, and 0-5, P, X and U
// once the cull area routes them) act only while the grid or loupe has focus,
// so their items take no key equivalent and name the key in their help
// instead ("Pick (P)"); a key with no route yet goes unnamed.
import LibraryModel
import SwiftUI

extension MenuCommand {
    /// One menu item: disabled while `action` is nil, with `reason` as its help.
    init(
        title: String, systemImage: String? = nil, action: LibraryMenu.Action?, reason: String, key: String? = nil,
        shortcut: KeyboardShortcut? = nil
    ) {
        let named = key.map { "\(title) (\($0))" } ?? title
        self.init(
            title, systemImage: systemImage, shortcut: shortcut, help: action == nil ? "\(named): \(reason)" : named,
            isEnabled: action != nil) { action?() }
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
            MenuCommand(
                title: "Import Folder…", systemImage: "folder.badge.plus", action: menu.file.importFolder,
                reason: menu.file.importHelp ?? why("importer", "Import isn't available right now."),
                shortcut: KeyboardShortcut("i", modifiers: [.command, .shift]))
            MenuCommand(
                title: "Load Sample Photos", systemImage: "photo.badge.plus", action: menu.edit.loadSamples,
                reason: why(nil, "This catalog was made by a newer Library. Update Library to open it."))
            MenuCommand(
                title: "Export…", systemImage: "square.and.arrow.up", action: menu.export.export,
                reason: menu.export.exportHelp ?? why("exporter", "Export isn't connected yet."),
                shortcut: KeyboardShortcut("e", modifiers: [.command, .shift]))
        }
        CommandGroup(replacing: .undoRedo) {
            MenuCommand(
                title: menu.edit.undoTitle, action: menu.edit.undo, reason: why(nil, "There is nothing to undo."),
                shortcut: KeyboardShortcut("z"))
            MenuCommand(
                title: menu.edit.redoTitle, action: menu.edit.redo, reason: why(nil, "There is nothing to redo."),
                shortcut: KeyboardShortcut("z", modifiers: [.command, .shift]))
        }
        CommandGroup(replacing: .pasteboard) {
            MenuCommand(
                title: "Select All", action: menu.edit.selectAll, reason: why(nil, "There are no photos to select."),
                shortcut: KeyboardShortcut("a"))
            MenuCommand(
                title: "Deselect", action: menu.edit.deselect, reason: why(nil, "No photos are selected."),
                shortcut: KeyboardShortcut("a", modifiers: [.command, .shift]))
        }
        CommandGroup(before: .toolbar) { viewItems }
        CommandMenu("Photo") { photoItems }
        CommandMenu("Metadata") { metadataItems }
    }

    @ViewBuilder private var viewItems: some View {
        let view = menu.view
        MenuCommand(
            title: "Grid", systemImage: "square.grid.2x2", action: view.grid,
            reason: why(nil, "The grid is already showing."), key: "G")
        MenuCommand(
            title: "Loupe", systemImage: "rectangle", action: view.loupe,
            reason: why(nil, "The loupe is already showing, or there are no photos."))
        Divider()
        // In the grid Zoom In/Out size the thumbnails (disabled at a limit);
        // in the loupe they wait on loupe zoom, which isn't wired yet.
        let inGrid = view.zoomInTitle == "Larger Thumbnails"
        let loupeZoom = why("loupe", "Zoom in the loupe isn't connected yet.")
        MenuCommand(
            title: view.zoomInTitle, systemImage: "plus.magnifyingglass", action: view.zoomIn,
            reason: inGrid ? why(nil, "Can't zoom in further.") : loupeZoom, shortcut: KeyboardShortcut("+"))
        MenuCommand(
            title: view.zoomOutTitle, systemImage: "minus.magnifyingglass", action: view.zoomOut,
            reason: inGrid ? why(nil, "Can't zoom out further.") : loupeZoom, shortcut: KeyboardShortcut("-"))
        MenuCommand(
            title: "Zoom to Fit", action: view.zoomToFit, reason: loupeZoom, shortcut: KeyboardShortcut("0"))
        MenuCommand(
            title: "Actual Size", action: view.actualSize, reason: loupeZoom, shortcut: KeyboardShortcut("1"))
        Divider()
        // A Menu of buttons, not a Picker: a Picker's .disabled didn't reach
        // the menu bar, while each item here is disabled by its nil action.
        let noSort = why(nil, "There are no photos to sort.")
        Menu("Sort By") {
            ForEach(LibrarySort.allCases, id: \.self) { sort in
                MenuCommand(
                    title: sort.rawValue, systemImage: sort == view.sort ? "checkmark" : nil,
                    action: bind(view.setSort, sort), reason: noSort)
            }
        }
        .disabled(view.setSort == nil)
        .help(view.setSort == nil ? "Sort By: \(noSort)" : "Sort By")
        Divider()
    }

    @ViewBuilder private var photoItems: some View {
        let photo = menu.photo
        let develop = why("develop", "Develop isn't connected yet.")
        let crop = why("crop", "Crop isn't connected yet.")
        MenuCommand(
            title: "Copy Settings", action: photo.copySettings, reason: develop,
            shortcut: KeyboardShortcut("c", modifiers: [.command, .shift]))
        MenuCommand(
            title: "Paste Settings", action: photo.pasteSettings, reason: develop,
            shortcut: KeyboardShortcut("v", modifiers: [.command, .shift]))
        MenuCommand(title: "Reset Develop", action: photo.resetDevelop, reason: develop)
        Divider()
        MenuCommand(title: photo.cropTitle, systemImage: "crop", action: photo.toggleCrop, reason: crop, key: "R")
        MenuCommand(title: "Reset Crop", action: photo.resetCrop, reason: crop)
    }

    @ViewBuilder private var metadataItems: some View {
        let cull = menu.cull
        let reason = why("culling", "Select photos first.")
        // A key goes in the help only while the cull area routes single keys.
        let routes = cull.key != nil
        let named: (String) -> String? = { routes ? $0 : nil }
        Menu("Set Rating") {
            ForEach(0...5, id: \.self) { stars in
                MenuCommand(
                    title: stars == 0 ? "No Stars" : stars == 1 ? "1 Star" : "\(stars) Stars",
                    action: bind(cull.setRating, stars), reason: reason, key: named("\(stars)"))
            }
        }
        Menu("Set Flag") {
            MenuCommand(title: "Pick", action: bind(cull.setFlag, .pick), reason: reason, key: named("P"))
            MenuCommand(title: "Reject", action: bind(cull.setFlag, .reject), reason: reason, key: named("X"))
            MenuCommand(title: "Clear Flag", action: bind(cull.setFlag, PhotoFlag.none), reason: reason, key: named("U"))
        }
        Menu("Set Label") {
            MenuCommand(title: "None", action: bind(cull.setLabel, nil), reason: reason)
            ForEach(PhotoLabel.allCases, id: \.self) { label in
                MenuCommand(title: label.rawValue, action: bind(cull.setLabel, label), reason: reason)
            }
        }
        Divider()
        let advance = why("culling", "Auto Advance isn't available yet.")
        Toggle(
            "Auto Advance",
            isOn: Binding(get: { menu.cull.autoAdvance }, set: { _ in menu.cull.toggleAutoAdvance?() })
        )
        .disabled(cull.toggleAutoAdvance == nil)
        .help(Self.autoAdvanceHelp(disabled: cull.toggleAutoAdvance == nil ? advance : nil))
    }

    /// Auto Advance's help: what it does while enabled (a label never moves
    /// the loupe), else `disabled`, the reason it is off.
    static func autoAdvanceHelp(disabled reason: String?) -> String {
        "Auto Advance: " + (reason ?? "In the loupe, go to the next photo after you set a rating or a flag.")
    }
}
