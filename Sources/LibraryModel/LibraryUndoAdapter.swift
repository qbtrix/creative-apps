// LibraryUndoAdapter.swift: undo and redo for the catalog on the kernel's History.
// Each step is named ("Set Rating", "Exposure") and holds the photos it
// changed as they were before it; undo puts them back by id and hands the
// kernel the photos it replaced, which redo puts back. A collections step
// ("New Collection") holds your collections before and after it; undo puts
// the before list back and redo the after list (FC-3), and undoing a delete
// selects the deleted collection again when it was selected (FC-9). A drop's
// "Import" step (LF-3) takes its photos out on undo and adds them back,
// selected, on redo. A "Delete Rejects" step (DR-6) holds the photos it
// trashed: undo puts each file back and the photo at its index, redo trashes
// the ones that came back again. Edits sharing an open coalesce key (one slider drag) stay
// one step. The 100-step limit is the kernel's. Undo and redo never move the
// loupe (#426); each names the photos whose develop it changed
// (`developChangedIDs`) for the window to redraw. Every step is recorded through CatalogHistory.record, which
// stamps an agent step's time for the AI tab (LibraryAgentActivity.swift).
// Linux-safe.

import SuiteKernel

/// One step's payload: the photos to put back, for a collections step
/// your collections before and after it (nil on a photo step), and for an
/// import step (LF-3) the photos its move takes out or adds back, and for a
/// Delete Rejects step (DR-6) the photos to put back or to trash again.
public struct CatalogChange: Hashable, Sendable {
    public internal(set) var photos: [PhotoItem]
    public internal(set) var collectionsBefore: [UserCollection]?
    public internal(set) var collectionsAfter: [UserCollection]?
    /// The collection selected before a collections step, which undo selects
    /// again when the step removed it (Delete Collection); nil on a photo step.
    public internal(set) var selectedBefore: String?
    public internal(set) var removing: [PhotoItem]?
    public internal(set) var adding: [PhotoItem]?
    /// Photos a Delete Rejects step took out, which applying the step puts back.
    public internal(set) var trashed: [TrashedPhoto]?
    /// Photos an undone Delete Rejects step put back, which applying it trashes again.
    public internal(set) var untrashed: [TrashedPhoto]?

    init(
        photos: [PhotoItem], collectionsBefore: [UserCollection]? = nil, collectionsAfter: [UserCollection]? = nil,
        selectedBefore: String? = nil, removing: [PhotoItem]? = nil, adding: [PhotoItem]? = nil,
        trashed: [TrashedPhoto]? = nil, untrashed: [TrashedPhoto]? = nil
    ) {
        self.trashed = trashed
        self.untrashed = untrashed
        self.photos = photos
        self.collectionsBefore = collectionsBefore
        self.collectionsAfter = collectionsAfter
        self.selectedBefore = selectedBefore
        self.removing = removing
        self.adding = adding
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

    /// How many steps the history keeps.
    static let limit = 100
    /// The kernel's history; each payload is the photos (and collections) to put back.
    public internal(set) var kernel = History<CatalogChange>(limit: CatalogHistory.limit)
    /// When each agent step was recorded (the AI tab's time; the kernel keeps no date).
    var agentDates = AgentStepDates()
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

    /// Records the step `name` that `change` undoes, stamping its time when an agent made it.
    /// Every catalog step goes through here.
    mutating func record(_ name: String, _ change: CatalogChange, key: String? = nil) {
        kernel.record(name, change, key: key)
        agentDates.stamp(kernel, limit: Self.limit)
    }
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
        history.record(name, CatalogChange(photos: before), key: coalesceKey)
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
        history.record(name, CatalogChange(
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
        let trash = services.trash
        var applied: CatalogChange?
        var trashing: (done: [TrashedPhoto], failed: [String])?
        let moved = move(&kernel) { change in
            applied = change
            let ids = Set(change.photos.map(\.id))
            var swapped = change
            swapped.photos = current.filter { ids.contains($0.id) }
            let out = Set((change.removing ?? []).map(\.id))
            swapped.adding = change.removing.map { _ in current.filter { out.contains($0.id) } }
            swapped.removing = change.adding
            if let trashed = change.trashed {
                trashing = Self.putBack(trashed, with: trash)
                (swapped.trashed, swapped.untrashed) = (nil, trashing?.done)
            } else if let untrashed = change.untrashed {
                trashing = Self.trashAgain(untrashed, in: current, with: trash)
                (swapped.trashed, swapped.untrashed) = (trashing?.done, nil)
            }
            return swapped
        }
        developChangedIDs = []
        guard moved, let applied else { return }
        let back = Dictionary(applied.photos.map { ($0.id, $0.develop) }, uniquingKeysWith: { first, _ in first })
        developChangedIDs = Set(current.lazy.filter { photo in back[photo.id].map { $0 != photo.develop } ?? false }.map(\.id))
        history.kernel = kernel
        history.open = false
        if let collections = applied[keyPath: side] { applyCollections(collections) }
        if side == \.collectionsBefore, let selected = applied.selectedBefore { reselect(selected, after: applied) }
        if !applied.photos.isEmpty { restore(applied.photos) }
        if let removing = applied.removing { removePhotos(Set(removing.map(\.id))) }
        if let adding = applied.adding {
            appendImported(adding)
            select(Set(adding.map(\.id)))
        }
        if let trashing {
            if applied.trashed != nil { insertPutBack(trashing.done) } else { takeOutTrashed(trashing.done) }
            cullError = trashing.failed.isEmpty ? nil : trashing.failed.joined(separator: " ")
        }
    }

    /// Takes the trashed photos out and remembers their paths, so a re-import skips them.
    mutating func takeOutTrashed(_ trashed: [TrashedPhoto]) {
        excludedPaths.formUnion(trashed.compactMap(\.photo.path))
        removePhotos(Set(trashed.map(\.photo.id)))
    }

    /// Puts the photos whose files came back at their indices, lowest first, and forgets their paths.
    private mutating func insertPutBack(_ back: [TrashedPhoto]) {
        for item in back.sorted(by: { $0.index < $1.index }) {
            items.insert(item.photo, at: min(max(item.index, 0), items.count))
            if let path = item.photo.path { excludedPaths.remove(path) }
        }
        recount()
        rebuildOrder()
        select(selection)
        saveRevision += 1
    }

    /// Moves each file back from the Trash; the ones that came back, and a line per one that didn't.
    private static func putBack(_ trashed: [TrashedPhoto], with trash: any PhotoTrashing)
        -> (done: [TrashedPhoto], failed: [String]) {
        var done: [TrashedPhoto] = [], failed: [String] = []
        for item in trashed {
            if let trashedPath = item.trashedPath, let path = item.photo.path {
                do { try trash.putBack(trashedPath, to: path) } catch {
                    failed.append(trashFailure("Couldn't put back", item.photo, error))
                    continue
                }
            }
            done.append(item)
        }
        return (done, failed)
    }

    /// Trashes again the photos an undo put back, each at its index in `current`.
    private static func trashAgain(_ photos: [TrashedPhoto], in current: [PhotoItem], with trash: any PhotoTrashing)
        -> (done: [TrashedPhoto], failed: [String]) {
        let ids = Set(photos.map(\.photo.id))
        var done: [TrashedPhoto] = [], failed: [String] = []
        for (index, photo) in current.enumerated() where ids.contains(photo.id) {
            guard let path = photo.path else {
                done.append(TrashedPhoto(photo: photo, index: index, trashedPath: nil))
                continue
            }
            do { done.append(TrashedPhoto(photo: photo, index: index, trashedPath: try trash.moveToTrash(path))) } catch {
                failed.append(trashFailure("Couldn't move", photo, error))
            }
        }
        return (done, failed)
    }

    /// Takes the photos with `ids` out (an import's undo); a loupe on one of them goes back to the grid.
    private mutating func removePhotos(_ ids: Set<String>) {
        items.removeAll { ids.contains($0.id) }
        if let focused = focusedItemID, ids.contains(focused) { (focusedItemID, mode) = (nil, .grid) }
        recount()
        rebuildOrder()
        select(selection)
        saveRevision += 1
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
