// RecentWork.swift: UC-2, the one recents list (tier 1). Foundation only
// for `Date`, Linux-safe, Sendable.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// UC-2 One recents list (tier 1). Live: `FileStore` over `recents.json`
/// plus SuiteShell's change notification.
public protocol RecentWork: Sendable {
    func list() async throws(SuiteError) -> RecentsList
    func note(_ ref: SuiteDocumentRef, event: RecentEvent, at date: Date, thumbnail: String?) async throws(SuiteError)
    func remove(fileID: String) async throws(SuiteError)
    func clear(app: SuiteApp) async throws(SuiteError)
    /// Yields the new revision after any process writes `recents.json`.
    func changes() async -> AsyncStream<Int>
}
