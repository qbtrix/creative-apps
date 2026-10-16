// FakePreferences.swift: the in-memory PreferencesStoring (UC-11). A save
// whose revision isn't the stored one is refused with `staleRevision`; a
// good save writes `revision + 1` and yields it on `changes()`. With
// `unavailable:` set, every throwing call throws `.notAvailable(that sentence)`.

public actor FakePreferences: PreferencesStoring {
    public private(set) var stored: SuitePreferences {
        didSet { if stored.revision != oldValue.revision { feed.send(stored.revision) } }
    }
    var feed = ChangeFeed()
    let unavailable: String?
    public init(_ p: SuitePreferences = SuitePreferences(), unavailable: String? = nil) { stored = p; self.unavailable = unavailable }
    public func load() throws(SuiteError) -> SuitePreferences { if let unavailable { throw .notAvailable(unavailable) }; return stored }
    public func save(_ p: SuitePreferences) throws(SuiteError) -> SuitePreferences {
        if let unavailable { throw .notAvailable(unavailable) }
        guard p.revision == stored.revision else { throw .staleRevision }
        var next = p
        next.revision += 1
        stored = next
        return next
    }
    public func changes() -> AsyncStream<Int> { feed.stream() }
}
