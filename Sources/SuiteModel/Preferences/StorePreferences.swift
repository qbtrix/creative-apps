// StorePreferences.swift: the live PreferencesStoring (UC-11) over FileStore's
// `preferences.json`, StoreRecents' shape. `load` returns the stored value
// with the store's revision (defaults at 0 when there is none). `save` takes
// only the stored revision: it writes revision + 1 under the store's lock
// (`write(expecting:)`, so a writer that slips in between still loses with
// `staleRevision`), yields it on `changes()` and calls
// `onWrite("preferences.json")`. `externalChange()` is what a watcher calls
// when another process wrote: it re-reads and yields a revision this
// instance has not yielded yet, once. Linux-safe.

/// The live PreferencesStoring (UC-11) over FileStore's preferences.json.
public actor StorePreferences: PreferencesStoring {
    static let file = "preferences.json"
    let store: FileStore
    let onWrite: @Sendable (String) -> Void
    var feed = ChangeFeed()
    /// The newest revision this instance wrote or yielded.
    var seen = 0

    public init(store: FileStore, onWrite: @escaping @Sendable (String) -> Void = { _ in }) {
        self.store = store
        self.onWrite = onWrite
    }

    /// The stored value with the store's revision; defaults when none.
    public func load() throws(SuiteError) -> SuitePreferences {
        let (value, revision) = try store.read(Self.file, as: SuitePreferences.self)
        var p = value ?? SuitePreferences()
        p.revision = revision
        return p
    }

    /// `.staleRevision` unless `p.revision` is the stored one; writes revision + 1, yields it, calls onWrite(file).
    public func save(_ p: SuitePreferences) throws(SuiteError) -> SuitePreferences {
        let current = try store.read(Self.file, as: SuitePreferences.self).revision
        guard p.revision == current else { throw .staleRevision }
        var next = p
        next.revision = current + 1
        try store.write(Self.file, next, expecting: current)
        seen = next.revision
        feed.send(seen)
        onWrite(Self.file)
        return next
    }

    public func changes() -> AsyncStream<Int> { feed.stream() }

    /// Another process wrote preferences.json: re-read it and yield its
    /// revision when this instance has not yielded it yet.
    public func externalChange() {
        guard let revision = try? store.read(Self.file, as: SuitePreferences.self).revision, revision > seen else { return }
        seen = revision
        feed.send(revision)
    }
}
