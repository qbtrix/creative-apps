// PreferencesStoring.swift: a suite contract from blueprint suite.md 5.2. Every throwing
// requirement throws `SuiteError`, whose `message` is the sentence the UI shows.

/// UC-11 Shared preferences (tier 2). Live: `FileStore` over `preferences.json`.
public protocol PreferencesStoring: Sendable {
    func load() async throws(SuiteError) -> SuitePreferences
    /// Writes `revision + 1`; `.staleRevision` when another writer won (the caller reloads).
    func save(_ preferences: SuitePreferences) async throws(SuiteError) -> SuitePreferences
    func changes() async -> AsyncStream<Int>
}
