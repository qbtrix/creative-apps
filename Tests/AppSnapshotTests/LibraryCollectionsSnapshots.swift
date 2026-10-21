// LibraryCollectionsSnapshots.swift: Keepers (3) selected under Collections,
// in a SuiteWindow built as `LibraryWindow.sidebarSections` builds it, and a
// new collection's empty state. Writes library-collections-sidebar-* and
// library-collection-empty-* (light, dark). FC-9 removes `.disabled`. macOS only.
import LibraryModel
import SuiteUI
import SwiftUI
import Testing

@testable import LibraryApp

@MainActor
@Suite struct LibraryCollectionsSnapshots {
    private func shoot() -> LibraryCatalog {
        var catalog = LibraryCatalog()
        catalog.load(LibraryFixtures.photos(named: "shoot"))
        catalog.setSort(.name)
        return catalog
    }

    @Test(.disabled("waits on FC-9")) func collectionsSidebar() throws {
        var catalog = shoot()
        catalog.select(Set(catalog.order.prefix(3)))
        catalog.newCollection()
        if let made = catalog.selectedUserCollection?.id { catalog.renameCollection(made, to: "Keepers") }
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .dark ? "dark" : "light"
            try snapshot(CollectionsWindow(model: catalog), name: "library-collections-sidebar-\(suffix)", scheme: scheme)
        }
    }

    @Test(.disabled("waits on FC-9")) func newCollectionIsEmpty() throws {
        var catalog = shoot()
        catalog.select([])
        catalog.newCollection()
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .dark ? "dark" : "light"
            try snapshot(LibraryBrowser(model: catalog), name: "library-collection-empty-\(suffix)", scheme: scheme)
        }
    }
}

/// The Library window's shell around `model`, its sidebar as LibraryWindow builds it; no state.
private struct CollectionsWindow: View {
    let model: LibraryCatalog

    var body: some View {
        SuiteWindow(
            title: "Library", sections: sections, selection: model.selectedCollectionID, onSelect: { _ in }
        ) {
            LibraryBrowser(model: model)
        } inspector: {
            EmptyView()
        }
        .frame(width: SuiteSize.windowLaunch.width, height: SuiteSize.windowLaunch.height)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var sections: [SidebarSection] {
        let rows = model.collections.map {
            SidebarItem(id: $0.id, title: $0.name, systemImage: LibraryWindow.symbol(for: $0.id), count: $0.count)
        }
        return [
            SidebarSection(id: "library", title: "Library", items: rows.filter { !UserCollection.isUserID($0.id) }),
            SidebarSection(
                id: "collections", title: "Collections", items: rows.filter { UserCollection.isUserID($0.id) },
                addAction: ToolbarAction("New Collection", systemImage: "plus", perform: {})),
        ]
    }
}
