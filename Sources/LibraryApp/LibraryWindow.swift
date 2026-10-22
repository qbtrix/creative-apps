// LibraryWindow.swift: the Library window. It is SuiteWindow with the
// collections in the sidebar, LibraryBrowser as content (with LibraryStatusBar
// under it in the loupe and on preview data), LibraryInspector in the inspector, and
// LibraryExportSheet while an export is under way. It owns the LibraryCatalog, hands its values and methods
// to the views, publishes the menu bar's LibraryMenu as a focused value, and
// publishes the `library.controls` JSON (LibraryControls.swift).
// The catalog starts from the launch arguments: a fixture's fakes and photos,
// or the live services over the Platform adapters.
//
// The sidebar has two sections: Library (All Photos, Picks, Recently
// Added) and Collections (yours, with New Collection as its add button and a
// double-click rename while those can act), then FOLDERS when the catalog's photos sit in any
// (LibraryFoldersSection.swift). LibraryFilterBar sits above
// LibraryBrowser; the hidden `library.collections` element carries the
// collections file's state for the journeys.
//
// The area hooks: each area (edit, import, thumbnails, cull, persist, loupe,
// develop, crop, export, filters) fills its own `LibraryWindow+<Area>.swift` with the
// LibraryMenu sub-struct it owns, its `<Area>AreaState` in `areas`, and the
// lifecycle hooks this body calls. The window's single keys go to the area
// that owns them through the menu; a nil action ignores the key.
import AppKit
import Foundation
import LibraryModel
import SuiteShell
import SuiteUI
import SwiftUI

/// One state object per area; each area adds its own properties to its class.
final class LibraryAreas {
    let edit = EditAreaState()
    let imports = ImportAreaState()
    let thumbnails = ThumbnailsAreaState()
    let cull = CullAreaState()
    let persist = PersistAreaState()
    let loupe = LoupeAreaState()
    let develop = DevelopAreaState()
    let crop = CropAreaState()
    let export = ExportAreaState()
    let filters = FiltersAreaState()
}

struct LibraryWindow: View {
    @State var model: LibraryCatalog
    @State var areas = LibraryAreas()

    /// `arguments` are the launch arguments (LibraryLaunch); a test passes a fixture's.
    init(arguments: [String] = ProcessInfo.processInfo.arguments) {
        let launch = LibraryLaunch(arguments: arguments)
        let services = launch.services(decoder: ImageIODecoder(), writer: JPEGWriter(), store: CatalogStore())
        _model = State(initialValue: LibraryCatalog(launch: launch, services: services))
    }

    #if DEBUG
    /// How many times a window's body ran; RenderBudgetLibraryTests counts an interaction's.
    static var bodyRuns = 0
    #endif

    var body: some View {
        #if DEBUG
        let _ = Self.bodyRuns += 1
        #endif
        let filters = filtersMenu
        SuiteWindow(
            title: "Library",
            sections: sidebarSections(filters),
            selection: model.sidebarSelection,
            // A FOLDERS row's click shows its folder (view.show-folder); any other row's selects its collection.
            onSelect: { model.selectSidebarRow($0) },
            onRename: filters.renameCollection,
            contextActions: { id in
                guard LibraryFolders.isRowID(id) else { return [] }
                return LibraryFoldersSection.actions(
                    help: model.showFolderHelp, show: { model.selectSidebarRow(id) },
                    toggleSubfolders: { model.toggleFolderSubfolders(row: id) })
            }
        ) {
            VStack(spacing: 0) {
                LibraryFilterBar(
                    filter: model.activeFilter, value: model.filterValue, caption: model.filterCaption, menu: filters)
                    .fixedSize(horizontal: false, vertical: true)
                LibraryBrowser(
                    // The store goes down unread, so a thumbnail pass reruns the grid, not this body.
                    model: model, menu: menu, thumbnails: areas.thumbnails.store, onSelect: { model.select($0) }, onOpen: { model.open($0) },
                    onStep: { model.stepLoupe(by: $0) }, onGrid: { model.showGrid() }, filters: filters)
                    // On the content, so it hears keys only while the grid or the loupe has focus.
                    .onKeyPress(phases: .down) { press in route(press) }
                if model.showsStatusBar {
                    // Keeps its height; the content above shrinks to fit.
                    LibraryStatusBar(model: model, fitScale: areas.loupe.fitScale)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } inspector: {
            LibraryInspector(
                model: model, menu: menu, onStar: { model.clickStar($0) }, onFlag: { model.setFlag($0) },
                onLabel: { model.setLabel($0) })
        }
        .focusedSceneValue(\.libraryMenu, menu)
        .focusedSceneValue(\.libraryCatalog, model)
        .focusedSceneValue(\.libraryFilters, filters)
        .suiteFileDrop(.library, bridge: LibraryShell.bridge, hasDocument: model.hasDocument,
                       places: model.placesExtensions, perform: { try? model.perform($0) })
        // The crop frame and the CROP section read these (crop CR-6).
        .environment(\.libraryCrop, cropControls)
        .libraryControlsProbe()
        .background { ProbeElement("library.collections", label: model.collectionsFileValue) }
        // The export area (LibraryWindow+Export.swift) moves `exportState` off `.idle`.
        .sheet(isPresented: Binding(get: { model.exportState != .idle }, set: { _ in })) { exportSheet }
        .modifier(backupArea)  // File > Restore Catalog Backup… (LibraryWindow+Backup.swift)
        .task {
            importAreaLaunch()
            persistAreaLaunch()
            filtersAreaLaunch()
        }
        .onChange(of: model.saveRevision) { _, _ in persistAreaChanged() }
        .onChange(of: model.focusedItemID) { _, _ in loupeAreaFocusChanged() }
        .onChange(of: model.mode) { _, _ in loupeAreaFocusChanged() }
        .onChange(of: model.catalogState) { _, _ in importAreaCatalogReady() }
        .onChange(of: model.collectionsRevision) { _, _ in filtersAreaChanged(areas.filters) }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            persistAreaFlush()
            filtersAreaFlush(areas.filters)
        }
    }

    /// The menu bar's items, each sub-struct from its area's file.
    var menu: LibraryMenu {
        var photo = developMenu
        let crop = cropMenu
        photo.toggleCrop = crop.toggleCrop
        photo.cropTitle = crop.cropTitle
        photo.applyCrop = crop.applyCrop
        photo.resetCrop = crop.resetCrop
        return LibraryMenu(
            edit: editMenu, file: fileMenu, thumbnails: thumbnailsMenu, cull: cullMenu, persist: persistMenu,
            view: viewMenu, photo: photo, export: exportMenu, share: shareMenu,
            reasons: model.services.unavailable)
    }

    /// A single key to the area that owns it; ignored (so the grid or the
    /// loupe can act) when it has a command modifier or its action is nil.
    private func route(_ press: KeyPress) -> KeyPress.Result {
        guard press.modifiers.isDisjoint(with: [.command, .control, .option]),
              let key = Self.libraryKey(press) else { return .ignored }
        let current = self.menu
        let action: LibraryMenu.Action?
        switch key {
        case .rating, .pick, .reject, .unflag, .label:
            guard let cull = current.cull.key else { return .ignored }
            cull(key)
            return .handled
        case .first: action = current.view.first
        case .last: action = current.view.last
        case .crop: action = current.photo.toggleCrop
        case .confirm: action = current.photo.applyCrop
        case .grid: action = current.view.grid
        }
        guard let action else { return .ignored }
        action()
        return .handled
    }

    /// Return, Home and End by their key; anything else by its one character.
    private static func libraryKey(_ press: KeyPress) -> LibraryKey? {
        switch press.key {
        case .return: return LibraryKey(special: .returnKey)
        case .home: return LibraryKey(special: .home)
        case .end: return LibraryKey(special: .end)
        default:
            guard press.characters.count == 1, let character = press.characters.first else { return nil }
            return LibraryKey(character: character)
        }
    }

    /// A menu action, nil (so the item disables) when it can't run.
    func enabled(_ allowed: Bool, _ perform: @escaping @MainActor () -> Void) -> (@MainActor () -> Void)? {
        allowed ? perform : nil
    }

    /// A one-argument menu action, nil (so the item disables) when it can't run.
    func enabled<Value>(_ allowed: Bool, _ perform: @escaping @MainActor (Value) -> Void) -> (@MainActor (Value) -> Void)? {
        allowed ? perform : nil
    }

    /// A two-argument menu action, nil (so the item disables) when it can't run.
    func enabled<First, Second>(
        _ allowed: Bool, _ perform: @escaping @MainActor (First, Second) -> Void
    ) -> (@MainActor (First, Second) -> Void)? {
        allowed ? perform : nil
    }

    /// Library: the built-in collections; Collections: yours, its add button
    /// New Collection, left off while it can't act (the header has no disabled state).
    func sidebarSections(_ filters: LibraryFiltersMenu) -> [SidebarSection] {
        let rows = model.collections.map {
            SidebarItem(id: $0.id, title: $0.name, systemImage: Self.symbol(for: $0.id), count: $0.count)
        }
        let add = filters.newCollection.map { ToolbarAction("New Collection", systemImage: "plus", perform: $0) }
        return [
            SidebarSection(id: "library", title: "Library", items: rows.filter { !UserCollection.isUserID($0.id) }),
            SidebarSection(
                id: "collections", title: "Collections", items: rows.filter { UserCollection.isUserID($0.id) },
                addAction: add),
        ] + [LibraryFoldersSection.section(LibraryFoldersSection.tree(model))].compactMap { $0 }
    }

    static func symbol(for collectionID: String) -> String {
        switch collectionID {
        case "favorites": "flag"
        case "recent": "clock"
        case let id where id.hasPrefix("smart-"): "gearshape"
        case let id where UserCollection.isUserID(id): "rectangle.stack"
        default: "photo.on.rectangle.angled"
        }
    }
}
