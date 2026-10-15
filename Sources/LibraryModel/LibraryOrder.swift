// LibraryOrder.swift: the cached display order (SP-8). `order` holds the
// selected collection's photo ids in the current sort; it is rebuilt once per
// change that can reorder or hide a photo (load, sort, collection, and an
// edit under the rating sort or in Favorites), so the grid, the selection and
// the loupe read it in O(n) instead of sorting on every read. Linux-safe.

extension LibraryCatalog {
    /// The selected collection's photos in the current sort order.
    public var sortedItems: [PhotoItem] {
        let byID = Dictionary(items.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return order.compactMap { byID[$0] }
    }

    /// Recomputes `order` from the shown photos and the sort: O(n log n).
    mutating func rebuildOrder() {
        let sort = sort
        order = shownItems.sorted { sort.orders($0, before: $1) }.map(\.id)
    }

    /// True when an edit to a photo's metadata can move or hide it in `order`.
    var editCanReorder: Bool { sort == .rating || selectedCollectionID == "favorites" }

    /// Sets the grid selection; ids not shown in the selected collection are dropped.
    public mutating func select(_ ids: Set<String>) {
        selection = ids.intersection(order)
    }

    /// Opens a shown photo in the loupe. An unknown id is ignored.
    public mutating func open(_ id: String) {
        guard order.contains(id) else { return }
        focusedItemID = id
        mode = .loupe
    }

    /// View > Loupe: opens the first selected photo in the sort, else the
    /// loupe's last photo, else the first shown. No photos: nothing changes.
    public mutating func showLoupe() {
        let last = focusedItemID.flatMap { order.contains($0) ? $0 : nil }
        guard let id = order.first(where: selection.contains) ?? last ?? order.first else { return }
        open(id)
    }

    /// Moves the loupe `steps` photos along the sort; it stops at the ends.
    public mutating func stepLoupe(by steps: Int) {
        guard mode == .loupe, let id = focusedItemID, let index = order.firstIndex(of: id) else { return }
        let last = order.count - 1
        // Clamp the step first so a huge count cannot overflow `Int`.
        focusedItemID = order[min(max(index + min(max(steps, -last), last), 0), last)]
    }

    /// Escape, G or View > Grid: back to the grid with the loupe's photo selected.
    public mutating func showGrid() {
        if mode == .loupe, let id = focusedItemID, order.contains(id) {
            selection = [id]
        }
        mode = .grid
    }
}
