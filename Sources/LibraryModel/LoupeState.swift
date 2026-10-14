// LoupeState.swift: what the loupe reads from LibraryCatalog: its photo, the
// "12 of 60" position in the current sort, whether Left and Right can move,
// and the artboard size CanvasSurface fits. Read-only; the loupe changes
// through LibraryCatalog's open, showLoupe, stepLoupe and showGrid. Linux-safe.

extension LibraryCatalog {
    /// The size the loupe draws a photo at, in pixels: a 4:3 camera frame, the
    /// grid cell's aspect, until import reads each file's real size (L2).
    public static let loupeArtboard = (width: 4032, height: 3024)

    /// The photo the loupe shows; nil in the grid or when it isn't shown.
    public var loupeItem: PhotoItem? {
        guard let place = loupePlace else { return nil }
        return place.items[place.index]
    }

    /// The loupe photo's place in the sort, e.g. "12 of 60"; nil in the grid.
    public var loupePosition: String? {
        loupePlace.map { "\($0.index + 1) of \($0.items.count)" }
    }

    public var canShowPreviousInLoupe: Bool { (loupePlace?.index ?? 0) > 0 }

    public var canShowNextInLoupe: Bool {
        loupePlace.map { $0.index < $0.items.count - 1 } ?? false
    }

    /// The shown photos in sort order and the loupe photo's index among them.
    private var loupePlace: (items: [PhotoItem], index: Int)? {
        guard mode == .loupe, let id = focusedItemID else { return nil }
        let items = sortedItems
        return items.firstIndex { $0.id == id }.map { (items, $0) }
    }
}
