// StorePreferences.swift: the live PreferencesStoring (UC-11) over FileStore's
// `preferences.json`, StoreRecents' shape. OB-1 stub: keeps the value in
// memory like FakePreferences (stale check, revision + 1, `changes()`);
// OB-9 reads and writes the store and makes `externalChange()` re-read.
// Linux-safe.

/// The live PreferencesStoring (UC-11) over FileStore's preferences.json.
public actor StorePreferences: PreferencesStoring {
    static let file = "preferences.json"
    let store: FileStore
    let onWrite: @Sendable (String) -> Void
    var feed = ChangeFeed()
    var stored = SuitePreferences()
    /// The newest revision this instance wrote or yielded.
    var seen = 0

    public init(store: FileStore, onWrite: @escaping @Sendable (String) -> Void = { _ in }) {
        self.store = store
        self.onWrite = onWrite
    }

    /// The stored value with the store's revision; defaults when none.
    public func load() throws(SuiteError) -> SuitePreferences { stored }

    /// `.staleRevision` unless `p.revision` is the stored one; writes revision + 1, yields it, calls onWrite(file).
    public func save(_ p: SuitePreferences) throws(SuiteError) -> SuitePreferences {
        guard p.revision == stored.revision else { throw .staleRevision }
        var next = p
        next.revision = next.revision < Int.max ? next.revision + 1 : 0
        stored = next
        seen = next.revision
        feed.send(seen)
        onWrite(Self.file)
        return next
    }

    public func changes() -> AsyncStream<Int> { feed.stream() }

    /// Another process wrote preferences.json: re-read and yield an unseen revision (OB-9).
    public func externalChange() {}
}
