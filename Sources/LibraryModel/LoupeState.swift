// LoupeState.swift: what the loupe reads from LibraryCatalog: its photo, the
// "12 of 60" position in the current sort, whether Left and Right can move,
// the photo's own size (the document CanvasViewport draws, LV-7), its help
// and its placeholder caption; and Home and End. The loupe
// changes through LibraryCatalog's open, showLoupe, stepLoupe, showGrid and
// the showFirstInLoupe / showLastInLoupe here. The readout with the photo's
// name is LibraryReadouts' loupeReadout. Linux-safe.

extension LibraryCatalog {
    /// The loupe photo's own size in pixels, each side at least 1: the document
    /// the loupe draws, so a portrait photo stands taller than wide. Nil in the grid.
    public var loupePhotoSize: PixelSize? {
        loupeItem.map { PixelSize(width: max($0.pixelSize.width, 1), height: max($0.pixelSize.height, 1)) }
    }

    /// The loupe photo's help: why its file can't be read, else why its last
    /// render failed ("Couldn't render this photo: …"); nil when neither or in the grid.
    public var loupeHelp: String? {
        guard let photo = loupeItem else { return nil }
        return photo.availability.help ?? loupeError
    }

    /// What the loupe shows with no picture yet: the photo's name and size,
    /// e.g. "IMG_0003  ·  4000 × 6000". Nil in the grid.
    public var loupePlaceholder: String? {
        guard let photo = loupeItem, let size = loupePhotoSize else { return nil }
        return "\(photo.name)  ·  \(size.width) × \(size.height)"
    }

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

    /// Home: the first photo in the sort. Does nothing in the grid.
    public mutating func showFirstInLoupe() { stepLoupe(by: Int.min) }

    /// End: the last photo in the sort. Does nothing in the grid.
    public mutating func showLastInLoupe() { stepLoupe(by: Int.max) }

    /// The shown photos in sort order and the loupe photo's index among them.
    private var loupePlace: (items: [PhotoItem], index: Int)? {
        guard mode == .loupe, let id = focusedItemID else { return nil }
        let items = sortedItems
        return items.firstIndex { $0.id == id }.map { (items, $0) }
    }
}
