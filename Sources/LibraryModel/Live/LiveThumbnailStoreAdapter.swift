// LiveThumbnailStoreAdapter.swift: Library's disk tier for grid thumbnails
// (shared-thumbnails ST-2 declares it, ST-6 connects it). ST-6 keeps
// `LiveThumbnails`' memory LRU and reads this before it decodes: CoreAsset's
// `ThumbnailStore` in `folder`, keyed by photo id, the develop token (content)
// and the grid bucket, under `budgetBytes`. Until then every read misses,
// writes are dropped and `stats` stays zero. Linux-safe, Sendable.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public struct LiveThumbnailStoreAdapter: Sendable {
    /// The store's folder.
    public let folder: String
    /// The most bytes the store keeps before it drops the oldest thumbnails.
    public let budgetBytes: Int

    public init(folder: String, budgetBytes: Int) throws {
        self.folder = folder
        self.budgetBytes = budgetBytes
    }

    /// The stored thumbnail for photo `id` at `content` (its develop token) and `bucket`, or nil.
    public func read(id: String, content: String, bucket: Int) -> Data? { nil }

    /// Stores a thumbnail for photo `id` at `content` and `bucket`.
    public func write(_ data: Data, id: String, content: String, bucket: Int) {}

    /// Thumbnails decoded and thumbnails served from disk since this adapter opened.
    public var stats: (decoded: Int, fromDisk: Int) { (0, 0) }
}
