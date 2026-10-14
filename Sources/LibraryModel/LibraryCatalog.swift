// LibraryCatalog.swift: the state behind Library's window: photos, collections
// with counts, the grid's sort, cell size and selection, and the browse mode.
// Linux-safe; LibraryApp changes it only through the methods here. Invariants:
// counts follow `items`; ids in `items` are unique; the selection holds only ids
// the collection shows.

/// A sidebar collection: a fixed source of photos.
public struct LibraryCollection: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public var count: Int
}

public struct LibraryCatalog: Sendable, Equatable {
    /// How many of the newest photos Recently Added shows.
    public static let recentLimit = 20
    /// The thumbnail cell's width step, in points; it stays in 80...320.
    public static let cellSizeStep = 40

    public private(set) var collections: [LibraryCollection] = [
        LibraryCollection(id: "all", name: "All Photos", count: 0),
        LibraryCollection(id: "favorites", name: "Favorites", count: 0),
        LibraryCollection(id: "recent", name: "Recently Added", count: 0),
    ]
    public private(set) var selectedCollectionID = "all"
    public private(set) var items: [PhotoItem] = []
    public private(set) var sort = LibrarySort.captureDate
    public private(set) var cellSize = 160
    public private(set) var selection: Set<String> = []
    public private(set) var mode = LibraryMode.grid
    public private(set) var focusedItemID: String?  // the loupe's photo

    public init() {}

    public var selectedCollection: LibraryCollection? {
        collections.first { $0.id == selectedCollectionID }
    }

    /// True when the catalog holds no photos at all.
    public var isEmpty: Bool { items.isEmpty }

    /// True when the selected collection shows no photos, even if the catalog has some.
    public var isSelectedCollectionEmpty: Bool { shownItems.isEmpty }

    /// The selected collection's photos in the current sort order.
    public var sortedItems: [PhotoItem] {
        shownItems.sorted { sort.orders($0, before: $1) }
    }

    public var canShowLargerThumbnails: Bool { cellSize < 320 }
    public var canShowSmallerThumbnails: Bool { cellSize > 80 }

    /// Selects a collection by id and clears the selection. An unknown id is ignored.
    public mutating func selectCollection(_ id: String) {
        guard collections.contains(where: { $0.id == id }) else { return }
        selectedCollectionID = id
        selection = []
    }

    public mutating func loadSamples(seed: UInt64 = LibrarySample.defaultSeed) {
        load(LibrarySample.items(seed: seed))
    }

    /// Replaces the photos, clears the selection and returns to the grid.
    /// A photo whose id is already taken gets the next free "<id>#2", "<id>#3", ...
    public mutating func load(_ photos: [PhotoItem]) {
        items = Self.uniquingIDs(photos)
        selection = []
        mode = .grid
        focusedItemID = nil
        let counts = ["all": items.count, "favorites": items.filter(\.isFlagged).count, "recent": recentItems.count]
        for index in collections.indices {
            collections[index].count = counts[collections[index].id] ?? 0
        }
    }

    public mutating func setSort(_ newSort: LibrarySort) { sort = newSort }

    /// One step larger (positive) or smaller (negative), clamped to 80...320.
    /// The step count is clamped first so a huge count cannot overflow `Int`.
    public mutating func stepCellSize(by steps: Int) {
        let span = (320 - 80) / Self.cellSizeStep
        let clampedSteps = min(max(steps, -span), span)
        cellSize = min(max(cellSize + clampedSteps * Self.cellSizeStep, 80), 320)
    }

    /// Sets the grid selection; ids not shown in the selected collection are dropped.
    public mutating func select(_ ids: Set<String>) {
        selection = ids.intersection(sortedItems.map(\.id))
    }

    /// Opens a shown photo in the loupe. An unknown id is ignored.
    public mutating func open(_ id: String) {
        guard sortedItems.contains(where: { $0.id == id }) else { return }
        focusedItemID = id
        mode = .loupe
    }

    /// View > Loupe: opens the first selected photo in the sort, else the
    /// loupe's last photo, else the first shown. No photos: nothing changes.
    public mutating func showLoupe() {
        let order = sortedItems.map(\.id)
        let last = focusedItemID.flatMap { order.contains($0) ? $0 : nil }
        guard let id = order.first(where: selection.contains) ?? last ?? order.first else { return }
        open(id)
    }

    /// Moves the loupe `steps` photos along the sort; it stops at the ends.
    public mutating func stepLoupe(by steps: Int) {
        let order = sortedItems.map(\.id)
        guard mode == .loupe, let id = focusedItemID, let index = order.firstIndex(of: id) else { return }
        let last = order.count - 1
        // Clamp the step first so a huge count cannot overflow `Int`.
        focusedItemID = order[min(max(index + min(max(steps, -last), last), 0), last)]
    }

    /// Escape, G or View > Grid: back to the grid with the loupe's photo selected.
    public mutating func showGrid() {
        if mode == .loupe, let id = focusedItemID, sortedItems.contains(where: { $0.id == id }) {
            selection = [id]
        }
        mode = .grid
    }

    /// The photos with every id unique; the first photo with an id keeps it.
    private static func uniquingIDs(_ photos: [PhotoItem]) -> [PhotoItem] {
        var taken = Set<String>()
        var nextSuffix: [String: Int] = [:]
        return photos.map { photo in
            var id = photo.id
            var suffix = nextSuffix[photo.id] ?? 2
            while taken.contains(id) {
                id = photo.id + "#" + String(suffix)
                suffix += 1
            }
            nextSuffix[photo.id] = suffix
            taken.insert(id)
            return id == photo.id ? photo : photo.withID(id)
        }
    }

    /// The selected collection's photos, unsorted.
    private var shownItems: [PhotoItem] {
        switch selectedCollectionID {
        case "favorites": items.filter(\.isFlagged)
        case "recent": recentItems
        default: items
        }
    }

    /// The newest `recentLimit` photos by capture date.
    private var recentItems: [PhotoItem] {
        Array(items.sorted { LibrarySort.captureDate.orders($1, before: $0) }.prefix(Self.recentLimit))
    }
}
