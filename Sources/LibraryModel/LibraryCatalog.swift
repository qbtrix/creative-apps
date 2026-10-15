// LibraryCatalog.swift: the state behind Library's window: photos, collections
// with counts, the grid's sort, cell size and selection, and the browse mode.
// Linux-safe; LibraryApp changes it only through the Model's methods. Invariants:
// counts follow `items`; ids in `items` are unique; the selection holds only ids
// the collection shows.

/// A sidebar collection: a fixed source of photos.
public struct LibraryCollection: Identifiable, Sendable, Hashable {
    public let id: String
    public let name: String
    public var count: Int
}

/// Where an import is: idle, or running with its progress.
public enum ImportState: Hashable, Sendable {
    case idle
    case running(ImportProgress)
}

/// The loupe's zoom: fit to the window, 100%, or a scale (1 is 100%).
public enum LoupeZoom: Hashable, Sendable {
    case fit, actual
    case scale(Double)
}

/// Where the export sheet is: closed, editing its options, writing, or done.
public enum ExportState: Hashable, Sendable {
    case idle
    case editing(ExportOptions)
    case running(done: Int, total: Int)
    case finished(ExportSummary)
}

/// A thumbnail asked of the services; `token` lets a stale answer be dropped.
public struct ThumbnailRequest: Hashable, Sendable {
    public var id: String
    public var longSide: Int
    public var token: Int
    public init(id: String, longSide: Int, token: Int) {
        self.id = id; self.longSide = longSide; self.token = token
    }
}

/// Stored state is `public internal(set)` (blueprint decision D6): the
/// Model's extension files write it; LibraryApp, another module, only reads it.
public struct LibraryCatalog: Sendable, Equatable {
    /// How many of the newest photos Recently Added shows.
    public static let recentLimit = 20
    /// The thumbnail cell's width step, in points; it stays in 80...320.
    public static let cellSizeStep = 40

    public internal(set) var collections: [LibraryCollection] = [
        LibraryCollection(id: "all", name: "All Photos", count: 0),
        LibraryCollection(id: "favorites", name: "Favorites", count: 0),
        LibraryCollection(id: "recent", name: "Recently Added", count: 0),
    ]
    public internal(set) var selectedCollectionID = "all"
    public internal(set) var items: [PhotoItem] = []
    public internal(set) var sort = LibrarySort.captureDate
    public internal(set) var cellSize = 160
    public internal(set) var selection: Set<String> = []
    public internal(set) var mode = LibraryMode.grid
    public internal(set) var focusedItemID: String?  // the loupe's photo

    public internal(set) var services: LibraryServices  // left out of ==
    public internal(set) var history = CatalogHistory()
    public internal(set) var order: [String] = []  // the shown ids in sort order; SP-8 fills it
    public internal(set) var importState = ImportState.idle
    public internal(set) var importNotice: ImportNotice?
    public internal(set) var thumbnails: [String: DisplayImage] = [:]
    public internal(set) var thumbnailLongSide = 512
    public internal(set) var pendingThumbnails: [String: ThumbnailRequest] = [:]
    public internal(set) var autoAdvance = true
    public internal(set) var loupeZoom = LoupeZoom.fit
    public internal(set) var loupeRender: RenderedPhoto?
    public internal(set) var loupeRenderToken = 0
    public internal(set) var loupeError: String?
    public internal(set) var copiedSettings: DevelopSettings?
    public internal(set) var cropDraft: CropSettings?  // non-nil while cropping
    public internal(set) var exportState = ExportState.idle
    public internal(set) var catalogState = CatalogFileState.ready
    public internal(set) var saveRevision = 0
    public internal(set) var savedRevision = 0
    public internal(set) var saveError: String?
    public internal(set) var showsTestValues = false  // -LibraryTestValues
    public internal(set) var cullError: String?  // a refused cull change

    public init(services: LibraryServices = .fake()) {
        self.services = services
    }

    /// Every stored property but `services`, whose members are existentials.
    public static func == (lhs: Self, rhs: Self) -> Bool {
        let browse = lhs.collections == rhs.collections && lhs.selectedCollectionID == rhs.selectedCollectionID
            && lhs.items == rhs.items && lhs.sort == rhs.sort && lhs.cellSize == rhs.cellSize
            && lhs.selection == rhs.selection && lhs.mode == rhs.mode && lhs.focusedItemID == rhs.focusedItemID
            && lhs.history == rhs.history && lhs.order == rhs.order
        let work = lhs.importState == rhs.importState && lhs.importNotice == rhs.importNotice
            && lhs.thumbnails == rhs.thumbnails && lhs.thumbnailLongSide == rhs.thumbnailLongSide
            && lhs.pendingThumbnails == rhs.pendingThumbnails && lhs.autoAdvance == rhs.autoAdvance
            && lhs.cullError == rhs.cullError && lhs.exportState == rhs.exportState
        let loupe = lhs.loupeZoom == rhs.loupeZoom && lhs.loupeRender == rhs.loupeRender
            && lhs.loupeRenderToken == rhs.loupeRenderToken && lhs.loupeError == rhs.loupeError
            && lhs.copiedSettings == rhs.copiedSettings && lhs.cropDraft == rhs.cropDraft
        let file = lhs.catalogState == rhs.catalogState && lhs.saveRevision == rhs.saveRevision
            && lhs.savedRevision == rhs.savedRevision && lhs.saveError == rhs.saveError
            && lhs.showsTestValues == rhs.showsTestValues
        return browse && work && loupe && file
    }

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
        recount()
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

    /// Applies `edit` to every selected photo, then keeps the counts and the
    /// selection true to the collection (unflagging in Favorites drops a photo).
    mutating func editSelected(_ edit: (inout PhotoItem) -> Void) {
        guard !selection.isEmpty else { return }
        for index in items.indices where selection.contains(items[index].id) {
            edit(&items[index])
        }
        recount()
        select(selection)
    }

    mutating func recount() {
        let counts = ["all": items.count, "favorites": items.filter(\.isFlagged).count, "recent": recentItems.count]
        for index in collections.indices {
            collections[index].count = counts[collections[index].id] ?? 0
        }
    }

    /// The photos with every id unique; the first photo with an id keeps it,
    /// and a later duplicate never takes an id another photo already owns.
    private static func uniquingIDs(_ photos: [PhotoItem]) -> [PhotoItem] {
        var taken = Set<String>()
        var keepsOwnID = [Bool]()
        keepsOwnID.reserveCapacity(photos.count)
        for photo in photos {
            keepsOwnID.append(taken.insert(photo.id).inserted)
        }
        var nextSuffix: [String: Int] = [:]
        return zip(photos, keepsOwnID).map { photo, keeps in
            if keeps { return photo }
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
