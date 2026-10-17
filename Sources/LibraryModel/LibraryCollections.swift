// LibraryCollections.swift: the collections you make (ids "user-<n>") and the
// smart collections (ids "smart-<n>"), their names and contents, and the
// refresh that keeps the selection and the loupe true to what is shown when
// the photos a collection shows change. Linux-safe.

/// A collection you made from a set of photos, or a smart collection whose
/// photos are the ones its rules admit.
public struct UserCollection: Identifiable, Hashable, Sendable {
    public enum Contents: Hashable, Sendable {
        case photos(Set<String>)
        case rules(LibraryFilter)
    }

    /// "user-<n>" or "smart-<n>", never reused while the collection exists.
    public let id: String
    public internal(set) var name: String
    public internal(set) var contents: Contents

    public init(id: String, name: String, contents: Contents) {
        self.id = id
        self.name = name
        self.contents = contents
    }

    /// Whether the collection's photos come from its rules, not from a set.
    public var isSmart: Bool {
        if case .rules = contents { true } else { false }
    }

    /// Whether `id` names a collection you made or a smart collection.
    public static func isUserID(_ id: String) -> Bool {
        id.hasPrefix("user-") || id.hasPrefix("smart-")
    }

    /// Set to nil by the task that builds each part (FC-9, FC-12, FC-14).
    public static let unavailable: String? = "Collections aren't built yet (filters-collections)."
    public static let smartUnavailable: String? = "Smart collections aren't built yet (filters-collections)."
    public static let fileUnavailable: String? = "Saving collections isn't built yet (filters-collections)."
}

extension LibraryCatalog {
    /// Rebuilds `order` from the shown photos, keeps the selection to the
    /// photos still shown, and returns the loupe to the grid when its photo
    /// is no longer shown (#156). Call it after any change to what a
    /// collection shows.
    mutating func refreshShown() {
        rebuildOrder()
        selection.formIntersection(order)
        if mode == .loupe, !(focusedItemID.map(order.contains) ?? false) {
            mode = .grid
            focusedItemID = nil
        }
    }
}
