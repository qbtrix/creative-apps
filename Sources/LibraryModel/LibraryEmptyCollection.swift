// LibraryEmptyCollection.swift: the copy for an empty collection in a catalog
// that has photos. Each message says what belongs there and how to fill it
// (docs/design.md, Empty states and messages). Linux-safe.

extension LibraryCollection {
    /// What the empty state says when this collection shows no photos.
    public var emptyMessage: String {
        switch id {
        case "favorites": "Flagged photos appear here. Flag a photo in All Photos to add it to Favorites."
        case "recent": "The newest photos appear here. Import or load photos to add them."
        default: "Photos in this collection appear here. Import or load photos to add them."
        }
    }

    /// The title of the empty state's button, which shows All Photos; nil for
    /// All Photos itself, which has nowhere else to fill from.
    public var emptyActionTitle: String? {
        id == "all" ? nil : "Show All Photos"
    }
}
