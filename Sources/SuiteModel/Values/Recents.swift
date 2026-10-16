// Recents.swift: what put a document on the recents list and one entry on
// it. The list itself is `RecentsList` (Recents/). Foundation only for
// `Date`, Linux-safe, Sendable.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// What an app did that put a document on the recents list.
public enum RecentEvent: String, Codable, Sendable { case opened, saved }

/// One document on the recents list.
public struct RecentItem: Hashable, Codable, Sendable {
    public var ref: SuiteDocumentRef
    public var lastUsed: Date
    public var thumbnail: String?    // path relative to the store: "thumbnails/<fileKey>.png" (SuiteDocumentRef.fileKey)
    public init(ref: SuiteDocumentRef, lastUsed: Date, thumbnail: String? = nil) {
        self.ref = ref; self.lastUsed = lastUsed; self.thumbnail = thumbnail
    }
}
