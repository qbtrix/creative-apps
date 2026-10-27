// LibraryServicesThumbnailDiskTests.swift: shared-thumbnails ST-7, Library's
// half (packet suiteui/features/shared-thumbnails.md). The window's live
// services gain the disk tier in `<support>/Library/Thumbnails`: a relaunch
// over the same folder draws the grid without decoding. Fakes and a store
// that won't open are left as they were. Linux-safe.
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
        let size = PixelSize(width: 600, height: 400)
        let out = maxLongSide.map { size.fitting(longSide: $0) } ?? size
        guard let image = DisplayImage(size: out, rgba8: [UInt8](repeating: 90, count: out.width * out.height * 4))
        else { throw LibraryError.notAnImage(path) }
        return image
    }
}

private func scratch() -> String {
    FileManager.default.temporaryDirectory.appendingPathComponent("LibraryServicesThumbnailDisk-" + UUID().uuidString).path
}

private func live(_ decoder: CountingDecoder) -> LibraryServices {
    LibraryServices.live(decoder: decoder, writer: FakeJPEGWriter(), store: FakeCatalogStore())
}

private let photos = (0..<3).map { index in
    PhotoItem(id: "b\(index)", name: "b\(index)", captureDate: Date(timeIntervalSince1970: Double(index)),
              color: Color3(0.5, 0.4, 0.3), path: "/beach/b\(index).jpg", pixelSize: PixelSize(width: 600, height: 400))
}

@Suite struct LibraryServicesThumbnailDiskTests {
    @Test func theFolderIsLibrarysUnderTheSupportRoot() {
        let folder = LibraryServices.thumbnailFolder(arguments: ["-SuiteSupportDir", "/tmp/suite"], home: "/Users/a")
        #expect(folder == "/tmp/suite/Library/Thumbnails")
    }

    @Test func aRelaunchOverTheSameFolderDecodesNothing() async throws {
        let folder = scratch()
        let first = CountingDecoder()
        let launched = live(first).withThumbnailDisk(folder: folder)
        for photo in photos { _ = try await launched.thumbnails.thumbnail(for: photo, longSide: 256) }
        #expect(await first.calls == 3)

        let again = CountingDecoder()
        let relaunched = live(again).withThumbnailDisk(folder: folder)
        for photo in photos { _ = try await relaunched.thumbnails.thumbnail(for: photo, longSide: 256) }
        #expect(await again.calls == 0, "the relaunch decoded instead of reading the disk")
        #expect(FileManager.default.fileExists(atPath: folder))
    }

    @Test func fakesAndAStoreThatWontOpenAreLeftAsTheyWere() async throws {
        let fake = LibraryServices.fake(photos)
        #expect(!(fake.withThumbnailDisk(folder: scratch()).thumbnails is LiveThumbnails))

        let blocked = scratch()
        try Data("a file".utf8).write(to: URL(fileURLWithPath: blocked))
        let services = live(CountingDecoder())
        let kept = services.withThumbnailDisk(folder: blocked)
        let before = try #require(services.thumbnails as? LiveThumbnails)
        let after = try #require(kept.thumbnails as? LiveThumbnails)
        #expect(before === after, "a store that won't open replaced the thumbnails")
    }
}
