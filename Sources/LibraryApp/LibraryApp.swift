// LibraryApp.swift: Library, the photo catalog app. The window is SuiteWindow
// with the collections in the sidebar, LibraryBrowser as content and the
// selected collection in the inspector. Views only read LibraryCatalog and
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
                onOpen: { model.open($0) })
        } inspector: {
            if let collection = model.selectedCollection {
                SurfaceCard(title: collection.name, detail: "\(collection.count) photos")
            }
        }
        .focusedSceneValue(\.libraryMenu, menu)
    }

    private var menu: LibraryMenu {
        LibraryMenu(
            sort: model.sort, loadSamples: { model.loadSamples() }, setSort: { model.setSort($0) },
            larger: stepCellSize(1, allowed: model.canShowLargerThumbnails),
            smaller: stepCellSize(-1, allowed: model.canShowSmallerThumbnails))
    }

    /// A thumbnail size step for the View menu, nil at the size limit.
    private func stepCellSize(_ steps: Int, allowed: Bool) -> (@MainActor () -> Void)? {
        guard allowed else { return nil }
        return { model.stepCellSize(by: steps) }
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
/// state without that button. Opening sets loupe mode; the loupe view is library-03.
struct LibraryBrowser: View {
    let model: LibraryCatalog
    var onLoadSamples: @MainActor () -> Void = {}
    var onSelect: @MainActor (Set<String>) -> Void = { _ in }
    var onOpen: @MainActor (String) -> Void = { _ in }

    var body: some View {
        if model.isEmpty {
            EmptyStateView(
                "No Photos", systemImage: "photo.stack",
                message: "Photos you import appear here, sorted by the date they were taken.",
                action: ToolbarAction("Load Sample Photos", systemImage: "photo.badge.plus", perform: onLoadSamples))
        } else if model.isSelectedCollectionEmpty {
            EmptyStateView(
                "No Photos in \(model.selectedCollection?.name ?? "This Collection")", systemImage: "photo.stack",
                message: "Photos in this collection appear here.")
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
                colorLabel: photo.label.map { (name: $0.rawValue, color: Self.labelColors[$0] ?? .secondary) }))
    }

    /// A one-pixel sRGB image from RGBA8 bytes; the cell stretches it to fill.
    private static func image(rgba: [UInt8]) -> Image? {
        guard rgba.count == 4, let space = CGColorSpace(name: CGColorSpace.sRGB),
              let provider = CGDataProvider(data: Data(rgba) as CFData),
              let pixel = CGImage(
                  width: 1, height: 1, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: 4, space: space,
                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)
        else { return nil }
        return Image(decorative: pixel, scale: 1)
    }

    private static let labelColors: [PhotoLabel: Color] = [.red: .red, .yellow: .yellow, .green: .green, .blue: .blue, .purple: .purple]
}
