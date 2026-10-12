// LibraryApp.swift: Library, the photo catalog app. The window is SuiteWindow
// with the collections in the sidebar, LibraryBrowser as content and the
// selected collection in the inspector. Views only read LibraryCatalog and
// call its methods; all state lives in LibraryModel (scripts/ci checks this).
import LibraryModel
import SuiteUI
import SwiftUI

@main
struct LibraryApp: App {
    var body: some Scene {
        WindowGroup { LibraryWindow() }
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
            LibraryBrowser(model: model)
        } inspector: {
            if let collection = model.selectedCollection {
                SurfaceCard(title: collection.name, detail: "\(collection.count) photos")
            }
        }
    }

    static func symbol(for collectionID: String) -> String {
        switch collectionID {
        case "favorites": "heart"
        case "recent": "clock"
        default: "photo.on.rectangle.angled"
        }
    }
}

/// The main content: the photo grid, or the empty state while the catalog is
/// empty. Import needs the file panel and the catalog (L1, L2); until then the
/// empty state has no button.
struct LibraryBrowser: View {
    let model: LibraryCatalog

    var body: some View {
        EmptyStateView(
            "No Photos", systemImage: "photo.stack",
            message: "Photos you import appear here, sorted by the date they were taken.")
    }
}
