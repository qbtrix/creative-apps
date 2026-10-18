// LibraryPersistence.swift: the catalog's side of saving to `catalog.json`
// (persist, PE-1). The launch read moves `catalogState` from `.loading` to
// `.ready`, `.damaged` or `.newer`; every change bumps `saveRevision`, and a
// save brings `savedRevision` up to the revision it wrote. The window's
// persist area does the file work and reports back through these methods.
// Linux-safe; no file access here.

extension LibraryCatalog {
    /// Starts the launch read: state `.loading` (import waits, nothing saves).
    public mutating func beginRestore() {
        catalogState = .loading
    }

    /// The decoded photos replace the catalog (ids kept as stored; of two
    /// with one id the first is kept); state `.ready`; saved. Called with nil
    /// when there is no file: keeps the current photos (a fixture's).
    public mutating func restore(_ photos: [PhotoItem]?) {
        if let photos {
            var seen = Set<String>()
            items = photos.filter { seen.insert($0.id).inserted }
            history = CatalogHistory()
            thumbnails = [:]
            pendingThumbnails = [:]
            selection = []
            mode = .grid
            focusedItemID = nil
            recount()
            rebuildOrder()
        }
        catalogState = .ready
        savedRevision = saveRevision
        saveError = nil
    }

    /// `.damagedCatalog` -> `.damaged` (the persist area set the file aside
    /// first); `.newerCatalog(v)` -> `.newer(version: v)`; anything else -> `.damaged`.
    public mutating func failRestore(_ error: LibraryError) {
        if case .newerCatalog(let version) = error {
            catalogState = .newer(version: version)
        } else {
            catalogState = .damaged
        }
    }

    /// What to write: nil when every change is saved or when
    /// `catalogState.canSave` is false (loading, or a newer file).
    public func saveRequest() -> (revision: Int, photos: [PhotoItem])? {
        guard catalogState.canSave, saveRevision != savedRevision else { return nil }
        return (saveRevision, items)
    }

    /// A save of `revision` finished. An older answer arriving late never
    /// moves `savedRevision` back, and no answer moves it past `saveRevision`.
    public mutating func didSave(revision: Int) {
        savedRevision = max(savedRevision, min(revision, saveRevision))
        saveError = nil
    }

    /// A save failed: keeps the reason; the catalog stays dirty, so the
    /// next change asks again.
    public mutating func failSave(_ error: LibraryError) {
        saveError = error.message
    }

    /// Marks the photos with these ids `.missing` (their files are gone at
    /// launch). Unknown ids are ignored; availability isn't saved, so the
    /// catalog stays as saved as it was.
    public mutating func markMissing(_ ids: Set<String>) {
        guard !ids.isEmpty else { return }
        for index in items.indices where ids.contains(items[index].id) {
            items[index].availability = .missing
        }
    }
}
