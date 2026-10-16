// LibraryImport.swift: the catalog's import state machine (import IM-1).
// beginImport hands the importer the ids to skip and marks the import
// running; batches arrive through appendImported, which drops ids already
// in the catalog; finishImport and failImport set the notice and go idle.
// An import is never an undo step (D4), but it does dirty the catalog file.
// Linux-safe.

extension LibraryCatalog {
    /// The known ids to skip, and state .running(0 of 0); nil while an import runs
    /// or while the catalog file is still loading (`catalogState == .loading`).
    public mutating func beginImport() -> Set<String>? {
        guard importState == .idle, catalogState != .loading else { return nil }
        importState = .running(ImportProgress(done: 0, total: 0))
        importNotice = nil
        return Set(items.map(\.id))
    }

    /// Shows the importer's progress; ignored when no import is running.
    public mutating func showImportProgress(_ progress: ImportProgress) {
        guard case .running = importState else { return }
        importState = .running(progress)
    }

    /// A batch from `added`: photos whose id is already in the catalog are ignored.
    public mutating func appendImported(_ photos: [PhotoItem]) {
        var known = Set(items.map(\.id))
        let fresh = photos.filter { known.insert($0.id).inserted }
        guard !fresh.isEmpty else { return }
        items += fresh
        recount()
        rebuildOrder()
        saveRevision += 1
    }

    /// Appends what `appendImported` missed, sets `importNotice`, state .idle.
    /// `folder` is the folder's last path component, kept by the import area
    /// (the spine declares no stored folder, and `ImportResult` has none).
    public mutating func finishImport(_ result: ImportResult, folder: String) {
        appendImported(result.added)
        importNotice = ImportNotice(
            folder: folder, added: result.added.count, alreadyKnown: result.alreadyKnown, failures: result.failures)
        importState = .idle
    }

    /// The whole import failed: the error notice, state .idle.
    public mutating func failImport(_ error: LibraryError, folder: String) {
        importNotice = ImportNotice(folder: folder, error: error)
        importState = .idle
    }

    /// The notice's close button.
    public mutating func dismissImportNotice() {
        importNotice = nil
    }

    /// "An import is already running." while one runs, else the importer's unavailable reason.
    public var importHelp: String? {
        if case .running = importState { return "An import is already running." }
        return LiveImporter.unavailable
    }
}
