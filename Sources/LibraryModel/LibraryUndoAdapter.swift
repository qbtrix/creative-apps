// LibraryUndoAdapter.swift: undo and redo for the catalog on the kernel's History.
// Each step is named ("Set Rating", "Exposure") and holds the photos it
// changed as they were before it; undo puts them back by id and hands the
// kernel the photos it replaced, which redo puts back. A collections step
// ("New Collection") holds your collections before and after it; undo puts
// the before list back and redo the after list (FC-3), and undoing a delete
// selects the deleted collection again when it was selected (FC-9). Edits
// sharing an open coalesce key (one slider drag) stay one step. The 100-step
// limit is the kernel's. Undo and redo never move the loupe (#426). Linux-safe.

import SuiteKernel

/// One step's payload: the photos to put back, and for a collections step
/// your collections before and after it (nil on a photo step).
public struct CatalogChange: Hashable, Sendable {
    public internal(set) var photos: [PhotoItem]
    public internal(set) var collectionsBefore: [UserCollection]?
    public internal(set) var collectionsAfter: [UserCollection]?
    /// The collection selected before a collections step, which undo selects
    /// again when the step removed it (Delete Collection); nil on a photo step.
    public internal(set) var selectedBefore: String?

    init(
        photos: [PhotoItem], collectionsBefore: [UserCollection]? = nil, collectionsAfter: [UserCollection]? = nil,
        selectedBefore: String? = nil
    ) {
        self.photos = photos
        self.collectionsBefore = collectionsBefore
        self.collectionsAfter = collectionsAfter
        self.selectedBefore = selectedBefore
    }
}

extension History<CatalogChange>.Step {
    /// The photos the step puts back.
    public var photos: [PhotoItem] { payload.photos }
    /// Your collections before a collections step; nil on a photo step.
    public var collectionsBefore: [UserCollection]? { payload.collectionsBefore }
    /// Your collections after a collections step; nil on a photo step.
    public var collectionsAfter: [UserCollection]? { payload.collectionsAfter }
}

/// The catalog's undo history: the kernel's steps of photos before an edit.
public struct CatalogHistory: Hashable, Sendable {
    public typealias Step = History<CatalogChange>.Step

    /// The kernel's history; each payload is the photos (and collections) to put back.
    public internal(set) var kernel = History<CatalogChange>(limit: 100)
    /// True while the top step can still take a coalesced edit.
    public internal(set) var open = false

    public init() {}

    /// Oldest first; the last is the step Undo reverts.
    public var undo: [Step] { kernel.undoSteps }
    /// Oldest undone last; the last is the step Redo reapplies.
    public var redo: [Step] { kernel.redoSteps }
    /// The step Undo would revert; nil when there is nothing to undo.
    public var top: Step? { kernel.undoSteps.last }
    /// The step Redo would reapply; nil when there is nothing to redo.
    public var redoTop: Step? { kernel.redoSteps.last }
}

extension LibraryCatalog {
    /// "Undo Set Rating"; nil when there is nothing to undo.
    public var undoTitle: String? { history.kernel.undoName.map { "Undo " + $0 } }

    /// "Redo Set Rating"; nil when there is nothing to redo.
    public var redoTitle: String? { history.kernel.redoName.map { "Redo " + $0 } }

    /// Applies `edit` to the photos with `ids` and records it as the step
    /// `name`. An edit that changes nothing records nothing. Edits sharing an
    /// open `coalesceKey` (one drag) stay one step until `endCoalescing()`.
    mutating func recordEdit(
        _ name: String, coalesceKey: String? = nil, ids: Set<String>, _ edit: (inout PhotoItem) -> Void
    ) {
        let indices = itemIndices(of: ids)
        let before = indices.map { items[$0] }
        for index in indices {
            edit(&items[index])
        }
        let after = indices.map { items[$0] }
        guard before != after else { return }
        saveRevision += 1
        history.kernel.record(name, CatalogChange(photos: before), key: coalesceKey)
        history.open = true
        refreshAfterHistoryChange(replacing: before, with: after)
    }

    /// Applies `edit` to `userCollections` and records it as the step `name`
    /// with the list before and after it. An edit that changes nothing records
    /// nothing. It never touches the photos or `saveRevision`.
    mutating func recordCollectionsEdit(_ name: String, _ edit: (inout [UserCollection]) -> Void) {
        var edited = userCollections
        edit(&edited)
        guard edited != userCollections else { return }
        history.kernel.record(name, CatalogChange(
            photos: [], collectionsBefore: userCollections, collectionsAfter: edited, selectedBefore: selectedCollectionID))
        history.open = false
        applyCollections(edited)
    }

    /// The indices in `items` of the photos with `ids`. One id (a single
    /// selection, the loupe) is found by a plain scan, with no id hashed;
    /// several through the set.
    private func itemIndices(of ids: Set<String>) -> [Int] {
        if ids.count == 1, let id = ids.first { return items.firstIndex { $0.id == id }.map { [$0] } ?? [] }
        return items.indices.filter { ids.contains(items[$0].id) }
    }

    /// Ends the current gesture: the next recorded edit is a new step.
    public mutating func endCoalescing() {
        history.kernel.endRun()
        history.open = false
    }

    /// Puts the top step's photos or collections back as they were; the loupe stays put.
    public mutating func undo() {
        step(\.collectionsBefore) { $0.undo($1) }
    }

    /// Reapplies the last undone step; the loupe stays put.
    public mutating func redo() {
        step(\.collectionsAfter) { $0.redo($1) }
    }

    /// Moves the kernel one step with `move`, then restores the collections
    /// list at `side` of a collections step and the photos it handed back.
    /// The kernel gets the photos they replace as the opposite step, and the
    /// collections snapshots unchanged; nothing changes when there is no step
    /// to move. A collections-only step leaves `saveRevision` alone.
    private mutating func step(
        _ side: KeyPath<CatalogChange, [UserCollection]?>,
        _ move: (inout History<CatalogChange>, (CatalogChange) -> CatalogChange) -> Bool
    ) {
        var kernel = history.kernel
        let current = items
        var applied: CatalogChange?
        let moved = move(&kernel) { change in
            applied = change
            let ids = Set(change.photos.map(\.id))
            var swapped = change
            swapped.photos = current.filter { ids.contains($0.id) }
            return swapped
        }
        guard moved, let applied else { return }
        history.kernel = kernel
        history.open = false
        if let collections = applied[keyPath: side] { applyCollections(collections) }
        if side == \.collectionsBefore, let selected = applied.selectedBefore { reselect(selected, after: applied) }
        if !applied.photos.isEmpty { restore(applied.photos) }
    }

    /// Puts `collections` in place as your collections and keeps what is shown
    /// true to them: a selected collection that is gone falls back to All
    /// Photos. The loupe stays put unless its photo is no longer shown (#156).
    private mutating func applyCollections(_ collections: [UserCollection]) {
        userCollections = collections
        collectionsRevision += 1
        let selected = selectedCollectionID
        if UserCollection.isUserID(selected), !collections.contains(where: { $0.id == selected }) {
            selectedCollectionID = "all"
        }
        recount()
        refreshShown()
    }

    /// Selects `id` again when the step being undone removed it while it was
    /// selected (Delete Collection), so undo shows what it showed before.
    private mutating func reselect(_ id: String, after change: CatalogChange) {
        let removed = !(change.collectionsAfter ?? []).contains { $0.id == id }
        guard removed, id != selectedCollectionID, userCollections.contains(where: { $0.id == id }) else { return }
        selectedCollectionID = id
        refreshShown()
    }

    /// Replaces each photo by id with its copy in `photos`, then refreshes.
    private mutating func restore(_ photos: [PhotoItem]) {
        let byID = Dictionary(photos.map { ($0.id, $0) }, uniquingKeysWith: { _, last in last })
        let indices = itemIndices(of: Set(byID.keys))
        let before = indices.map { items[$0] }
        for index in indices {
            if let photo = byID[items[index].id] { items[index] = photo }
        }
        let after = indices.map { items[$0] }
        saveRevision += 1
        refreshAfterHistoryChange(replacing: before, with: after)
    }

    /// Keeps the counts, the order and the selection true after an edit,
    /// undo or redo that replaced `before` with `after` in place. Counts move
    /// by the changed photos alone; `order` and the selection are rebuilt
    /// only when the edit can move or hide a photo, since otherwise `order`
    /// is unchanged and the selection already lies within it. It never
    /// touches `mode` or `focusedItemID`.
    private mutating func refreshAfterHistoryChange(replacing before: [PhotoItem], with after: [PhotoItem]) {
        recount(replacing: before, with: after)
        guard editCanReorder else { return }
        rebuildOrder()
        select(selection)
    }
}
