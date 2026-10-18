// LibraryWindow.swift: the Library window. It is SuiteWindow with the
// collections in the sidebar, LibraryBrowser as content (with its status bar
// under it on preview data), LibraryInspector in the inspector, and
// LibraryExportSheet while an export is under way. It owns the LibraryCatalog, hands its values and methods
// to the views, publishes the menu bar's LibraryMenu as a focused value, and
// publishes the `library.controls` JSON (LibraryControls.swift).
// The catalog starts from the launch arguments: a fixture's fakes and photos,
// or the live services over the Platform adapters.
//
// The area hooks: each area (edit, import, thumbnails, cull, persist, loupe,
// develop, crop, export) fills its own `LibraryWindow+<Area>.swift` with the
// LibraryMenu sub-struct it owns, its `<Area>AreaState` in `areas`, and the
// lifecycle hooks this body calls. The window's single keys go to the area
// that owns them through the menu; a nil action ignores the key.
import AppKit
import Foundation
import LibraryModel
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
}

struct LibraryWindow: View {
    /// What the "Preview data" pill means, as its tooltip and accessibility hint.
    static let previewHelp = "This window shows built-in sample data, not photos on disk."

    /// The status bar under the browser: the photo count, then the "Preview data" pill on the fakes.
    static func statusBar(_ model: LibraryCatalog) -> some View {
        ViewerStatusBar(
            zoom: 1, size: LibraryCatalog.photoCountText(model.items.count),
            preview: model.services.isPreview ? (previewHelp, "library.status.preview") : nil)
    }

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
        SuiteWindow(
            title: "Library",
            sidebarTitle: "Collections",
            items: model.collections.map {
                SidebarItem(id: $0.id, title: $0.name, systemImage: Self.symbol(for: $0.id), count: $0.count)
            },
            selection: model.selectedCollectionID,
            onSelect: { model.selectCollection($0) }
        ) {
            VStack(spacing: 0) {
                LibraryBrowser(
                    model: model, menu: menu, onSelect: { model.select($0) }, onOpen: { model.open($0) },
                    onStep: { model.stepLoupe(by: $0) }, onGrid: { model.showGrid() })
                    // On the content, so it hears keys only while the grid or the loupe has focus.
                    .onKeyPress(phases: .down) { press in route(press) }
                if model.services.isPreview {
                    // Keeps its height; the content above shrinks to fit.
                    Self.statusBar(model).fixedSize(horizontal: false, vertical: true)
                }
            }
        } inspector: {
            LibraryInspector(
                model: model, onStar: { model.clickStar($0) }, onFlag: { model.setFlag($0) },
                onLabel: { model.setLabel($0) })
        }
        .focusedSceneValue(\.libraryMenu, menu)
        .libraryControlsProbe()
        // The export area moves `exportState` off `.idle`; nothing does in wave 1.
        .sheet(isPresented: Binding(get: { model.exportState != .idle }, set: { _ in })) {
            LibraryExportSheet()
        }
        .task {
            importAreaLaunch()
            persistAreaLaunch()
        }
        .onChange(of: model.saveRevision) { _, _ in persistAreaChanged() }
        .onChange(of: model.focusedItemID) { _, _ in loupeAreaFocusChanged() }
        .onChange(of: model.catalogState) { _, _ in importAreaCatalogReady() }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            persistAreaFlush()
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
            view: viewMenu, photo: photo, export: exportMenu, reasons: model.services.unavailable)
    }

    /// A single key to the area that owns it; ignored (so the grid or the
    /// loupe can act) when it has a command modifier or its action is nil.
    private func route(_ press: KeyPress) -> KeyPress.Result {
        guard press.modifiers.isDisjoint(with: [.command, .control, .option]),
              let key = Self.libraryKey(press) else { return .ignored }
        let current = self.menu
        let action: LibraryMenu.Action?
        switch key {
        case .rating, .pick, .reject, .unflag:
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

    static func symbol(for collectionID: String) -> String {
        switch collectionID {
        case "favorites": "heart"
        case "recent": "clock"
        default: "photo.on.rectangle.angled"
        }
    }
}
