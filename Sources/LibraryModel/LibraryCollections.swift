// LibraryCollections.swift: the collections you make (ids "user-<n>") and the
// smart collections (ids "smart-<n>"), their names and contents, and the
// refresh that keeps the selection and the loupe true to what is shown when
// the photos a collection shows change. Until each part is built (FC-9,
// FC-14), the editing and file calls change nothing and their help answers
// the `unavailable` text. Linux-safe.

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

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
    public static let smartUnavailable: String? = nil
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

    /// The selected collection of yours, or nil for a built-in one.
    public var selectedUserCollection: UserCollection? {
        guard UserCollection.isUserID(selectedCollectionID) else { return nil }
        return userCollections.first { $0.id == selectedCollectionID }
    }

    /// Makes "New Collection" from the cull targets; returns its id, or ""
    /// while collections are unavailable.
    @discardableResult public mutating func newCollection() -> String {
        guard UserCollection.unavailable == nil else { return "" }
        return ""
    }

    /// Rename (built-ins ignored), add `ids` (the menu and a drop), add the
    /// cull targets, remove the cull targets, and delete a collection of yours.
    public mutating func renameCollection(_ id: String, to name: String) {
        guard UserCollection.unavailable == nil else { return }
    }
    public mutating func add(_ ids: Set<String>, to id: String) {
        guard UserCollection.unavailable == nil else { return }
    }
    public mutating func addToCollection(_ id: String) { add(cullTargets, to: id) }
    public mutating func removeFromCollection() { guard removeFromCollectionHelp == nil else { return } }
    public mutating func deleteCollection(_ id: String) { guard deleteCollectionHelp == nil else { return } }

    public func addToCollectionHelp(_ id: String) -> String? { UserCollection.unavailable }
    public var removeFromCollectionHelp: String? { UserCollection.unavailable }
    public var deleteCollectionHelp: String? { UserCollection.unavailable }

    /// The collections file to write, or nil when nothing needs saving.
    public func collectionsSaveRequest() -> (revision: Int, data: Data)? {
        guard UserCollection.fileUnavailable == nil else { return nil }
        return nil
    }

    /// Records that the file for `revision` was written.
    public mutating func didSaveCollections(revision: Int) {
        guard UserCollection.fileUnavailable == nil else { return }
    }

    /// Restores your collections from the file's `data` (nil: no file).
    public mutating func restoreCollections(_ data: Data?) throws {
        guard UserCollection.fileUnavailable == nil else { return }
    }

    /// A file that couldn't be read was set aside as `name`.
    public mutating func failRestoreCollections(setAsideAs name: String) {
        guard UserCollection.fileUnavailable == nil else { return }
    }

    /// "saved" or "dirty", for the journeys.
    public var collectionsFileValue: String {
        collectionsRevision == collectionsSavedRevision ? "saved" : "dirty"
    }
}
