// LibraryCatalog.swift: the state behind Library's window (photo catalog).
// Holds the sidebar's collections with their photo counts and the selected
// collection. Linux-safe: no UI imports. LibraryApp changes it only through
// the methods here. The catalog database (L1) and import plan (L2) replace the
// fixed collections with real queries.

/// A sidebar collection: a fixed source of photos.
public struct LibraryCollection: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public var count: Int
}

public struct LibraryCatalog: Sendable, Equatable {
    public private(set) var collections: [LibraryCollection] = [
        LibraryCollection(id: "all", name: "All Photos", count: 0),
        LibraryCollection(id: "favorites", name: "Favorites", count: 0),
        LibraryCollection(id: "recent", name: "Recently Added", count: 0),
    ]
    public private(set) var selectedCollectionID = "all"

    public init() {}

    public var selectedCollection: LibraryCollection? {
        collections.first { $0.id == selectedCollectionID }
    }

    /// True when the catalog holds no photos at all.
    public var isEmpty: Bool {
        collections.first { $0.id == "all" }?.count == 0
    }

    /// Selects a collection by id. An unknown id is ignored.
    public mutating func selectCollection(_ id: String) {
        if collections.contains(where: { $0.id == id }) { selectedCollectionID = id }
    }
}
