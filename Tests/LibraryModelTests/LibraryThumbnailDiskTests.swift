// LibraryThumbnailDiskTests.swift: shared-thumbnails ST-1 writes it, ST-6 turns
// it on (MJ-ST step 3, packet suiteui/features/shared-thumbnails.md). Library's
// grid keeps its memory LRU and gains CoreAsset's disk store as a second tier
// (`LiveThumbnailStoreAdapter`): import 50 photos and draw the grid (50
// decodes), rebuild the services on the same folder and draw again (zero
// decodes, every thumbnail from disk), then change one photo's exposure (one
// decode: the develop token is part of the content key, so the old picture is
// never read). `Services` builds `LiveThumbnails` over the adapter.
import CoreColor
import CoreRaster
import Foundation
import Testing

@testable import LibraryModel

/// A decoder that answers every path with flat bytes at the asked size and counts its calls.
private actor CountingDecoder: PhotoDecoding {
    private(set) var calls = 0

    func scan(folder: String) async throws -> FolderScan { FolderScan(candidates: [], failures: []) }

    func decode(path: String, maxLongSide: Int?) async throws -> DisplayImage {
        calls += 1
        let size = PixelSize(width: 1200, height: 800)
        let out = maxLongSide.map { size.fitting(longSide: $0) } ?? size
        guard let image = DisplayImage(size: out, rgba8: [UInt8](repeating: 128, count: out.width * out.height * 4))
        else { throw LibraryError.notAnImage(path) }
        return image
    }
}

/// One launch's thumbnail services over the disk store in `folder`.
private struct Services {
    let decoder = CountingDecoder()
    let store: LiveThumbnailStoreAdapter
    let thumbnails: LiveThumbnails

    init(folder: String) throws {
        store = try LiveThumbnailStoreAdapter(folder: folder, budgetBytes: 512 * 1024 * 1024)
        // Built over `store`, so a miss in memory reads the disk before it decodes.
        thumbnails = LiveThumbnails(decoder: decoder, develop: LiveDevelop(), disk: store)
    }

    /// Draws every photo's grid cell at the 256 bucket.
    func drawGrid(_ photos: [PhotoItem]) async throws {
        for photo in photos { _ = try await thumbnails.thumbnail(for: photo, longSide: 256) }
    }
}

/// The 50 imported photos, each a file on disk.
private func imported() -> [PhotoItem] {
    (0..<50).map { index in
        PhotoItem(id: "p\(index)", name: "p\(index)", captureDate: Date(timeIntervalSince1970: Double(index)),
                  color: Color3(0.2, 0.4, 0.6), path: "/shoot/p\(index).jpg", pixelSize: PixelSize(width: 1200, height: 800))
    }
}

private func scratch() -> String {
    FileManager.default.temporaryDirectory.appendingPathComponent("LibraryThumbnailDiskTests-" + UUID().uuidString).path
}

@Suite struct LibraryThumbnailDiskTests {
    @Test
    func relaunchDecodesNothing() async throws {
        let folder = scratch(), photos = imported()
        let first = try Services(folder: folder)
        try await first.drawGrid(photos)
        #expect(await first.decoder.calls == 50)
        #expect(first.store.stats.decoded == 50)
        #expect(first.store.stats.fromDisk == 0)

        let relaunched = try Services(folder: folder)
        try await relaunched.drawGrid(photos)
        #expect(await relaunched.decoder.calls == 0)
        #expect(relaunched.store.stats.decoded == 0)
        #expect(relaunched.store.stats.fromDisk == 50)
    }

    @Test
    func staleAfterDevelop() async throws {
        let folder = scratch()
        var photos = imported()
        try await Services(folder: folder).drawGrid(photos)

        let relaunched = try Services(folder: folder)
        try await relaunched.drawGrid(photos)
        photos[0].develop = photos[0].develop.setting(.exposure, to: 1)
        try await relaunched.drawGrid(photos)
        #expect(await relaunched.decoder.calls == 1)
        #expect(relaunched.store.stats.decoded == 1)
        #expect(relaunched.store.stats.fromDisk == 50)
    }
}
