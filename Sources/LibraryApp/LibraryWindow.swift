// LibraryWindow.swift: the Library window. It is SuiteWindow with the
// collections in the sidebar, LibraryBrowser as content and LibraryInspector
// in the inspector. It owns the LibraryCatalog, hands its values and methods
// to the views, and publishes the menu bar's LibraryMenu as a focused value.
// The catalog starts from the launch arguments: a fixture's fakes and photos,
// or the live services over the Platform adapters.
import Foundation
import LibraryModel
import SuiteUI
import SwiftUI

struct LibraryWindow: View {
    @State private var model: LibraryCatalog

    init() {
        let launch = LibraryLaunch(arguments: ProcessInfo.processInfo.arguments)
        let services = launch.services(decoder: ImageIODecoder(), writer: JPEGWriter(), store: CatalogStore())
        _model = State(initialValue: LibraryCatalog(launch: launch, services: services))
    }

    var body: some View {
        SuiteWindow(
            title: "Library",
            sidebarTitle: "Collections",
            items: model.collections.map {
                SidebarItem(id: $0.id, title: $0.name, systemImage: Self.symbol(for: $0.id), count: $0.count)
            },
            selection: model.selectedCollectionID,
            onSelect: { model.selectCollection($0) }
        ) {
            LibraryBrowser(
                model: model, onLoadSamples: { model.loadSamples() }, onSelect: { model.select($0) },
                onOpen: { model.open($0) }, onStep: { model.stepLoupe(by: $0) }, onGrid: { model.showGrid() })
        } inspector: {
            LibraryInspector(
                model: model, onStar: { model.clickStar($0) }, onFlag: { model.setFlag($0) },
                onLabel: { model.setLabel($0) })
        }
        .focusedSceneValue(\.libraryMenu, menu)
    }

    private var menu: LibraryMenu {
        let inGrid = model.mode == .grid
        return LibraryMenu(
            edit: LibraryMenu.Edit(loadSamples: { model.loadSamples() }),
            cull: LibraryMenu.Cull(
                setRating: { model.setRating($0) }, setFlag: { model.setFlag($0) }, setLabel: { model.setLabel($0) }),
            view: LibraryMenu.Viewing(
                grid: enabled(model.mode == .loupe) { model.showGrid() },
                loupe: enabled(inGrid && !model.isSelectedCollectionEmpty) { model.showLoupe() },
                zoomIn: stepCellSize(1, allowed: inGrid && model.canShowLargerThumbnails),
                zoomOut: stepCellSize(-1, allowed: inGrid && model.canShowSmallerThumbnails),
                setSort: { model.setSort($0) }, sort: model.sort,
                zoomInTitle: inGrid ? "Larger Thumbnails" : "Zoom In",
                zoomOutTitle: inGrid ? "Smaller Thumbnails" : "Zoom Out"),
            reasons: model.services.unavailable)
    }

    /// A thumbnail size step for the View menu, nil at the size limit.
    private func stepCellSize(_ steps: Int, allowed: Bool) -> (@MainActor () -> Void)? {
        guard allowed else { return nil }
        return { model.stepCellSize(by: steps) }
    }

    /// A menu action, nil (so the item disables) when it can't run.
    private func enabled(_ allowed: Bool, _ perform: @escaping @MainActor () -> Void) -> (@MainActor () -> Void)? {
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
