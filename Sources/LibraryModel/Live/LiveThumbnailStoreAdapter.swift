// LiveThumbnailStoreAdapter.swift: Library's disk tier for grid thumbnails
// (shared-thumbnails ST-6). `LiveThumbnails` keeps its memory LRU and reads
// this before it decodes: CoreAsset's `ThumbnailStore` in `folder`, keyed by
// photo id, a content key (the file's size and modification time and the
// develop token, so a changed file or develop setting never reads an old
// picture) and the grid bucket, under `budgetBytes`. Thumbnails are stored as
// PNG. `stats` counts decodes and disk hits since this adapter opened, shared
// by its copies. Linux-safe, Sendable.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreAsset
import CoreRaster
import Synchronization

public struct LiveThumbnailStoreAdapter: Sendable {
    /// The store's folder.
    public let folder: String
    /// The most bytes the store keeps before it drops the oldest thumbnails.
    public let budgetBytes: Int

    private let store: ThumbnailStore
    private let counts: Counts

    /// Decodes and disk hits, one box every copy of the adapter shares.
    private final class Counts: Sendable {
        let value = Mutex((decoded: 0, fromDisk: 0))
    }

    public init(folder: String, budgetBytes: Int) throws {
        self.folder = folder
        self.budgetBytes = budgetBytes
        store = try ThumbnailStore(folder: URL(fileURLWithPath: folder), budgetBytes: budgetBytes)
        counts = Counts()
    }

    /// The stored thumbnail for photo `id` at `content` and `bucket`, or nil; a hit counts as from disk.
    public func read(id: String, content: String, bucket: Int) -> Data? {
        guard let data = try? store.read(key(id, content, bucket)) else { return nil }
        counts.value.withLock { $0.fromDisk += 1 }
        return data
    }

    /// Stores a thumbnail for photo `id` at `content` and `bucket`, made by a decode, so it counts as decoded.
    public func write(_ data: Data, id: String, content: String, bucket: Int) {
        counts.value.withLock { $0.decoded += 1 }
        try? store.write(data, for: key(id, content, bucket), volume: nil, relativePath: nil)
    }

    /// Thumbnails decoded and thumbnails served from disk since this adapter opened.
    public var stats: (decoded: Int, fromDisk: Int) { counts.value.withLock { $0 } }

    /// The store's key: the bucket picks the smallest size class that covers it.
    private func key(_ id: String, _ content: String, _ bucket: Int) -> PreviewKey {
        let size = SizeClass.allCases.first { $0.rawValue >= bucket } ?? .large
        return PreviewKey(asset: id, content: content, size: size)
    }

    /// `photo`'s content key at `longSide`: its file's size and modification time, and the develop token.
    public static func content(of photo: PhotoItem, longSide: Int) -> String {
        let attributes = photo.path.flatMap { try? FileManager.default.attributesOfItem(atPath: $0) } ?? [:]
        let size = attributes[.size].map { "\($0)" } ?? "-"
        let modified = (attributes[.modificationDate] as? Date).map { "\($0.timeIntervalSince1970)" } ?? "-"
        return "\(size)-\(modified)-\(ThumbnailToken.of(photo.develop, longSide: longSide))"
    }

    /// `photo`'s stored thumbnail at `longSide`, decoded from its PNG, or nil on a miss or a damaged entry.
    func image(for photo: PhotoItem, longSide: Int) -> DisplayImage? {
        guard let data = read(id: photo.id, content: Self.content(of: photo, longSide: longSide), bucket: longSide),
              let buffer = try? PNG.read(data), let bytes = try? buffer.rgba8(colorSpace: .sRGB) else { return nil }
        return DisplayImage(size: PixelSize(width: buffer.width, height: buffer.height), rgba8: bytes)
    }

    /// Stores `image`, `photo`'s thumbnail at `longSide`, as PNG.
    func store(_ image: DisplayImage, for photo: PhotoItem, longSide: Int) {
        guard let buffer = try? PixelBuffer(rgba8: image.rgba8, width: image.size.width, height: image.size.height, colorSpace: .sRGB),
              let png = try? PNG.write(buffer) else { return }
        write(png, id: photo.id, content: Self.content(of: photo, longSide: longSide), bucket: longSide)
    }
}
