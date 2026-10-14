// LibraryApp.swift: Library, the photo catalog app. The window is SuiteWindow
// with the collections in the sidebar, LibraryBrowser as content and, in the
// inspector, the selected photos' MetadataInspector or else the selected
// collection. Views only read LibraryCatalog and
// call its methods; all state lives in LibraryModel (scripts/ci checks this).
// The menu bar (LibraryCommands) reaches the window through a focused value.
import LibraryModel
import SuiteUI
import SwiftUI

@main
struct LibraryApp: App {
    var body: some Scene {
        WindowGroup { LibraryWindow() }
            .commands { LibraryCommands() }
    }
}

struct LibraryWindow: View {
    @State private var model = LibraryCatalog()

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
            if let metadata = model.selectedMetadata {
                MetadataInspector(
                    metadata: metadata, onStar: { model.clickStar($0) }, onFlag: { model.setFlag($0) },
                    onLabel: { model.setLabel($0) })
            } else if let collection = model.selectedCollection {
                SurfaceCard(title: collection.name, detail: "\(collection.count) photos")
            }
        }
        .focusedSceneValue(\.libraryMenu, menu)
    }

    private var menu: LibraryMenu {
        LibraryMenu(
            sort: model.sort, loadSamples: { model.loadSamples() }, setSort: { model.setSort($0) },
            larger: stepCellSize(1, allowed: model.canShowLargerThumbnails),
            smaller: stepCellSize(-1, allowed: model.canShowSmallerThumbnails),
            showGrid: enabled(model.mode == .loupe) { model.showGrid() },
            showLoupe: enabled(model.mode == .grid && !model.isSelectedCollectionEmpty) { model.showLoupe() })
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

/// The photo grid, or the empty state whose button loads the samples until
/// import lands (L2); an empty collection in a non-empty catalog gets an empty
/// state that says how to fill it, with a button back to All Photos. In loupe
/// mode it shows the loupe's photo (LibraryLoupe) instead of the grid.
struct LibraryBrowser: View {
    let model: LibraryCatalog
    var onLoadSamples: @MainActor () -> Void = {}
    var onSelect: @MainActor (Set<String>) -> Void = { _ in }
    var onOpen: @MainActor (String) -> Void = { _ in }
    var onShowAll: @MainActor () -> Void = {}
    var onStep: @MainActor (Int) -> Void = { _ in }
    var onGrid: @MainActor () -> Void = {}

    var body: some View {
        if model.isEmpty {
            EmptyStateView(
                "No Photos", systemImage: "photo.stack",
                message: "Photos you import appear here, sorted by the date they were taken.",
                action: ToolbarAction("Load Sample Photos", systemImage: "photo.badge.plus", perform: onLoadSamples))
        } else if model.isSelectedCollectionEmpty, let collection = model.selectedCollection {
            EmptyStateView(
                "No Photos in \(collection.name)", systemImage: "photo.stack", message: collection.emptyMessage,
                action: collection.emptyActionTitle.map {
                    ToolbarAction($0, systemImage: "photo.on.rectangle.angled", perform: onShowAll)
                })
        } else if let photo = model.loupeItem, let position = model.loupePosition {
            LibraryLoupe(photo: photo, position: position, onStep: onStep, onGrid: onGrid)
        } else {
            let side = CGFloat(model.cellSize)
            ThumbnailGrid(
                model.sortedItems.map { ThumbnailItem<String>(photo: $0) }, cellSize: CGSize(width: side, height: side * 3 / 4),
                selection: model.selection, onSelectionChange: onSelect, onOpen: onOpen)
        }
    }
}

extension ThumbnailItem where ID == String {
    /// A grid cell for a photo: its flat color, file name, and rating, flag and label badges.
    init(photo: PhotoItem) {
        self.init(
            id: photo.id, image: Self.image(rgba: photo.pixel), caption: photo.name,
            badges: ThumbnailBadges(
                rating: photo.rating, isFlagged: photo.isFlagged,
                colorLabel: photo.label.map { (name: $0.rawValue, color: $0.color) }))
    }

    /// A one-pixel sRGB image from RGBA8 bytes; the cell and the loupe stretch it to fill.
    static func image(rgba: [UInt8]) -> Image? {
        guard rgba.count == 4, let space = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: Data(rgba) as CFData),
              let pixel = CGImage(
                  width: 1, height: 1, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 4, space: space,
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { return nil }
        return Image(decorative: pixel, scale: 1)
    }
}
