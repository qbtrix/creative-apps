// RecentsList.swift: the one recents list every suite process reads and
// writes. Newest first, one entry per file, at most 200; filter, search
// and the merge two racing writers need. Foundation free, Linux-safe.

/// The one recents list. Newest first, one entry per file, at most `cap`.
public struct RecentsList: Codable, Equatable, Sendable {
    public static let cap = 200
    public var revision: Int
    public private(set) var items: [RecentItem]

    public init(revision: Int = 0, items: [RecentItem] = []) {
        self.revision = revision
        self.items = []
        for item in items { note(item) }
    }

    /// Puts the item in date order, replacing an older entry for the same file.
    public mutating func note(_ item: RecentItem) {
        items.removeAll { $0.ref.fileID == item.ref.fileID }
        let at = items.firstIndex { $0.lastUsed < item.lastUsed } ?? items.count
        items.insert(item, at: at)
        if items.count > Self.cap { items.removeLast(items.count - Self.cap) }
    }

    public mutating func remove(fileID: String) { items.removeAll { $0.ref.fileID == fileID } }
    public mutating func clear(app: SuiteApp) { items.removeAll { $0.ref.app == app } }

    /// Items for one app (nil: all) whose name contains the query, any case.
    public func filtered(app: SuiteApp?, query: String) -> [RecentItem] {
        let q = query.lowercased()
        return items.filter { item in
            (app == nil || item.ref.app == app) && (q.isEmpty || item.ref.displayName.lowercased().contains(q))
        }
    }

    /// Two writers raced: keep the newest entry per file from both.
    public func merging(_ other: RecentsList) -> RecentsList {
        var merged = RecentsList(revision: max(revision, other.revision), items: items)
        for item in other.items {
            if let mine = merged.items.first(where: { $0.ref.fileID == item.ref.fileID }), mine.lastUsed >= item.lastUsed {
                continue
            }
            merged.note(item)
        }
        return merged
    }
}
