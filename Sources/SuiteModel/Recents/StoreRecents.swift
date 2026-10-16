// StoreRecents.swift: the live RecentWork (UC-2) over FileStore's
// `recents.json`. Every write runs under the store's lock through
// `update`, bumps the revision, yields it on `changes()` and calls
// `onWrite("recents.json")` so a watcher can tell other processes.
// `externalChange()` is what that watcher calls when another process
// wrote: it re-reads and yields a revision it has not seen. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The live recents list, shared by every suite process through one folder.
public actor StoreRecents: RecentWork {
    static let file = "recents.json"
    let store: FileStore
    let onWrite: @Sendable (String) -> Void
    var feed = ChangeFeed()
    /// The newest revision this instance wrote or yielded.
    var seen = 0

    public init(store: FileStore, onWrite: @escaping @Sendable (String) -> Void = { _ in }) {
        self.store = store
        self.onWrite = onWrite
    }

    public func list() throws(SuiteError) -> RecentsList {
        let (value, revision) = try store.read(Self.file, as: RecentsList.self)
        var list = value ?? RecentsList()
        list.revision = revision
        return list
    }

    /// Re-noting a file without a thumbnail keeps the one it had.
    public func note(_ ref: SuiteDocumentRef, event: RecentEvent, at date: Date, thumbnail: String?) throws(SuiteError) {
        try write { list in
            let keep = list.items.first { $0.ref.fileID == ref.fileID }?.thumbnail
            list.note(RecentItem(ref: ref, lastUsed: date, thumbnail: thumbnail ?? keep))
        }
    }

    public func remove(fileID: String) throws(SuiteError) {
        try write { $0.remove(fileID: fileID) }
    }

    public func clear(app: SuiteApp) throws(SuiteError) {
        try write { $0.clear(app: app) }
    }

    public func changes() -> AsyncStream<Int> { feed.stream() }

    /// Another process wrote `recents.json`: re-read it and yield its
    /// revision when this instance has not seen it yet.
    public func externalChange() async {
        guard let revision = try? store.read(Self.file, as: RecentsList.self).revision, revision != seen else { return }
        seen = revision
        feed.send(revision)
    }

    private func write(_ change: (inout RecentsList) -> Void) throws(SuiteError) {
        let (_, revision) = try store.update(Self.file, empty: RecentsList()) { old in
            var list = old
            change(&list)
            list.revision += 1
            return list
        }
        seen = revision
        feed.send(revision)
        onWrite(Self.file)
    }
}
