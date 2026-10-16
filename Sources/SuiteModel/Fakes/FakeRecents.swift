// FakeRecents.swift: the in-memory RecentWork (UC-2). Re-noting a file
// without a thumbnail keeps the one it had. With `unavailable:` set, every
// throwing call throws `.notAvailable(that sentence)`.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public actor FakeRecents: RecentWork {
    public private(set) var stored: RecentsList {
        didSet { if stored.revision != oldValue.revision { feed.send(stored.revision) } }
    }
    var feed = ChangeFeed()
    let unavailable: String?
    public init(_ list: RecentsList = RecentsList(), unavailable: String? = nil) { stored = list; self.unavailable = unavailable }
    public func list() throws(SuiteError) -> RecentsList { if let unavailable { throw .notAvailable(unavailable) }; return stored }
    public func note(_ ref: SuiteDocumentRef, event: RecentEvent, at date: Date, thumbnail: String?) throws(SuiteError) {
        if let unavailable { throw .notAvailable(unavailable) }
        let keep = stored.items.first { $0.ref.fileID == ref.fileID }?.thumbnail
        stored.note(RecentItem(ref: ref, lastUsed: date, thumbnail: thumbnail ?? keep))
        stored.revision += 1
    }
    public func remove(fileID: String) throws(SuiteError) {
        if let unavailable { throw .notAvailable(unavailable) }
        stored.remove(fileID: fileID); stored.revision += 1
    }
    public func clear(app: SuiteApp) throws(SuiteError) {
        if let unavailable { throw .notAvailable(unavailable) }
        stored.clear(app: app); stored.revision += 1
    }
    public func changes() -> AsyncStream<Int> { feed.stream() }
}
