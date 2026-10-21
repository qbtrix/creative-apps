// LibraryEmptyCollection.swift: the copy for an empty collection in a catalog
// that has photos. Each message says what belongs there and how to fill it
// (docs/design.md, Empty states and messages). Linux-safe.

extension LibraryCollection {
    /// What the empty state says when this collection shows no photos.
    public var emptyMessage: String {
        switch id {
        case "favorites": "Picked photos appear here. Pick a photo in All Photos (press P) to add it to Picks."
        case "recent": "The newest photos appear here. Import or load photos to add them."
        case _ where id.hasPrefix("user-"):
            "Select photos in All Photos, then choose Photo > Add to Collection or drag them here."
        case _ where id.hasPrefix("smart-"):
            "Photos that match this collection's rules appear here. Change the rules in the filter bar."
        default: "Photos in this collection appear here. Import or load photos to add them."
        }
    }

    /// The title of the empty state's button, which shows All Photos; nil for
    /// All Photos itself, which has nowhere else to fill from.
    public var emptyActionTitle: String? {
        id == "all" ? nil : "Show All Photos"
    }
}

extension LibraryCatalog {
    /// What the grid says when the filter hides every photo of a collection.
    public var filterEmptyMessage: String {
        "No photos in \(selectedCollection?.name ?? "All Photos") match \(activeFilter.summary)."
    }
}
