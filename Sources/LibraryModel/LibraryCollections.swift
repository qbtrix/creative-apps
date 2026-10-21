// LibraryCollections.swift: the collections you make (ids "user-<n>") and the
// smart collections (ids "smart-<n>"), their names and contents, and the
// refresh that keeps the selection and the loupe true to what is shown when
// the photos a collection shows change. New, rename, add, remove and delete
// are each one named undo step (FC-9). Until the file is built (FC-14), its
// calls change nothing. Linux-safe.

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
    public static let unavailable: String? = nil
    public static let smartUnavailable: String? = "Smart collections aren't built yet (filters-collections)."
    public static let fileUnavailable: String? = "Saving collections isn't built yet (filters-collections)."

    /// The set's photo ids; empty for a smart collection.
    var photoIDs: Set<String> {
        if case .photos(let ids) = contents { ids } else { [] }
    }
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

    /// Makes "New Collection" from the cull targets as one step, selects it
    /// and returns its id ("user-<max n + 1>"), or "" while collections are
    /// unavailable. Its name is "Untitled Collection", then " 2", " 3", ...
    @discardableResult public mutating func newCollection() -> String {
        guard UserCollection.unavailable == nil else { return "" }
        let numbers = userCollections.compactMap { $0.id.hasPrefix("user-") ? Int($0.id.dropFirst(5)) : nil }
        let id = "user-\((numbers.max() ?? 0) + 1)"
        let made = UserCollection(id: id, name: untitledName, contents: .photos(cullTargets))
        recordCollectionsEdit("New Collection") { $0.append(made) }
        selectCollection(id)
        return id
    }

    /// Renames a collection of yours to `name` trimmed, as one step; an
    /// empty name or a built-in id changes nothing.
    public mutating func renameCollection(_ id: String, to name: String) {
        guard UserCollection.unavailable == nil, UserCollection.isUserID(id) else { return }
        let trimmed = String(name.drop(while: \.isWhitespace).reversed().drop(while: \.isWhitespace).reversed())
        guard !trimmed.isEmpty else { return }
        recordCollectionsEdit("Rename Collection") { list in
            for index in list.indices where list[index].id == id { list[index].name = trimmed }
        }
    }

    /// Adds `ids` (the menu's cull targets or a drop) to a collection you
    /// made, as one step; refused with `addToCollectionHelp`'s reasons.
    public mutating func add(_ ids: Set<String>, to id: String) {
        guard addHelp(ids, to: id) == nil else { return }
        recordCollectionsEdit("Add to Collection") { list in
            for index in list.indices where list[index].id == id {
                list[index].contents = .photos(list[index].photoIDs.union(ids))
            }
        }
    }
    public mutating func addToCollection(_ id: String) { add(cullTargets, to: id) }

    /// Takes the cull targets out of the selected collection you made, as one step.
    public mutating func removeFromCollection() {
        guard removeFromCollectionHelp == nil, let id = selectedUserCollection?.id else { return }
        let targets = cullTargets
        recordCollectionsEdit("Remove from Collection") { list in
            for index in list.indices where list[index].id == id {
                list[index].contents = .photos(list[index].photoIDs.subtracting(targets))
            }
        }
    }

    /// Deletes a collection of yours as one step; its photos stay in the catalog.
    public mutating func deleteCollection(_ id: String) {
        guard UserCollection.unavailable == nil, UserCollection.isUserID(id) else { return }
        recordCollectionsEdit("Delete Collection") { $0.removeAll { $0.id == id } }
    }

    /// Why the cull targets can't go into `id`; nil when they can.
    public func addToCollectionHelp(_ id: String) -> String? { addHelp(cullTargets, to: id) }

    /// Why Remove from Collection can't run; nil when it can.
    public var removeFromCollectionHelp: String? {
        if let unavailable = UserCollection.unavailable { return unavailable }
        guard let collection = selectedUserCollection, !collection.isSmart else {
            return "Open a collection you made to remove photos from it."
        }
        guard !collection.photoIDs.isDisjoint(with: cullTargets) else {
            return "Select photos in \(collection.name) to remove them."
        }
        return nil
    }

    /// Why Delete Collection can't run on the selected collection; nil when it can.
    public var deleteCollectionHelp: String? {
        if let unavailable = UserCollection.unavailable { return unavailable }
        return selectedUserCollection == nil ? "Select a collection you made to delete it." : nil
    }

    /// Why `ids` can't go into `id`: not a collection you made with a set of
    /// photos, nothing to add, or every one already in it.
    private func addHelp(_ ids: Set<String>, to id: String) -> String? {
        if let unavailable = UserCollection.unavailable { return unavailable }
        guard let collection = userCollections.first(where: { $0.id == id }), !collection.isSmart else {
            return "Add photos to a collection you made; smart and built-in collections choose their own."
        }
        if ids.isEmpty { return "Select photos to add them to \(collection.name)." }
        if ids.isSubset(of: collection.photoIDs) { return "Every selected photo is already in \(collection.name)." }
        return nil
    }

    /// "Untitled Collection", or the first " <n>" from 2 not taken by one of yours.
    private var untitledName: String {
        let base = "Untitled Collection"
        let taken = Set(userCollections.map(\.name))
        guard taken.contains(base) else { return base }
        var number = 2
        while taken.contains("\(base) \(number)") { number += 1 }
        return "\(base) \(number)"
    }

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
