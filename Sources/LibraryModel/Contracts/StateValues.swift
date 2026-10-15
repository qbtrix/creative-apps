// Contracts/StateValues.swift: the values behind the import and export
// notices and the catalog file's state, with the exact text the window
// shows, so journeys and Linux tests assert the same strings. The spine
// declares these with the catalog's stored state; features only fill them.
/// What the last import did; the content's notice shows `message`.
public struct ImportNotice: Hashable, Sendable {
    public var folder: String
    public var added: Int
    public var alreadyKnown: Int
    public var failures: [FileFailure]
    /// Set when the whole import failed (unreadable folder, no photos).
    public var error: LibraryError?
    public init(folder: String, added: Int = 0, alreadyKnown: Int = 0, failures: [FileFailure] = [],
                error: LibraryError? = nil) {
        self.folder = folder; self.added = added; self.alreadyKnown = alreadyKnown
        self.failures = failures; self.error = error
    }

    public var message: String {
        if let error { return error.message }
        let failed = failures.isEmpty ? "" : failures.count == 1
            ? " 1 file couldn't be imported." : " \(failures.count) files couldn't be imported."
        if added == 0 { return failures.isEmpty ? "No new photos in \(folder)." : String(failed.dropFirst()) }
        return (added == 1 ? "Imported 1 photo." : "Imported \(added) photos.") + failed
    }
    /// The notice's state: error when nothing came in and something failed.
    public var isError: Bool { error != nil || (added == 0 && !failures.isEmpty) }
}

/// How an export ended; the sheet shows `message`, `failures` and, when
/// any failed, Try Again (`LibraryCatalog.retryExport()` re-plans `failedIDs`).
public struct ExportSummary: Hashable, Sendable {
    public var total: Int
    public var written: [String]
    public var failures: [FileFailure]
    public var failedIDs: [String]
    public var cancelled: Bool
    public init(total: Int, written: [String], failures: [FileFailure] = [], failedIDs: [String] = [],
                cancelled: Bool = false) {
        self.total = total; self.written = written; self.failures = failures
        self.failedIDs = failedIDs; self.cancelled = cancelled
    }

    public var message: String {
        if cancelled { return "Exported \(written.count) of \(total). Export was cancelled." }
        if !failures.isEmpty {
            return failures.count == 1 ? "1 photo couldn't be exported." : "\(failures.count) photos couldn't be exported."
        }
        return written.count == 1 ? "Exported 1 photo." : "Exported \(written.count) photos."
    }
}

/// The catalog file at launch and after; the content's notice shows `message`.
public enum CatalogFileState: Hashable, Sendable {
    case loading, ready
    /// The file was set aside as `catalog.json.bad`; the catalog starts empty.
    case damaged
    /// A newer Library wrote it; it is left untouched and nothing is saved over it.
    case newer(version: Int)

    public var message: String? {
        switch self {
        case .loading, .ready: nil
        case .damaged: LibraryError.damagedCatalog("").message
        case .newer(let version): LibraryError.newerCatalog(version: version).message
        }
    }
    /// False while loading and for `.newer`: saving would overwrite a file
    /// this Library can't read.
    public var canSave: Bool {
        switch self {
        case .ready, .damaged: true
        case .loading, .newer: false
        }
    }
}
