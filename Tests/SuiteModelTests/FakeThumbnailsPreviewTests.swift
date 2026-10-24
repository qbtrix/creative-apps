// FakeThumbnailsPreviewTests.swift: shared-thumbnails ST-2. The fake's read
// side: a seeded ref returns its fixture PNG (a real PNG, the same bytes each
// run, one per ref), a publish reads back, an unknown ref and an unavailable
// fake return nil.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel
import Testing

@Suite struct FakeThumbnailsPreviewTests {
    func ref(_ name: String) -> SuiteDocumentRef {
        let path = "/tmp/Documents/" + name
        return SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: .design,
                                type: .designDocument, displayName: name)
    }

    @Test func aSeededRefReturnsItsFixturePNG() async throws {
        let beach = ref("Beach.design"), dock = ref("Dock.design")
        let thumbnails = FakeThumbnails(seeded: [beach, dock])
        let bytes = try #require(await thumbnails.preview(for: beach))
        #expect(Array(bytes.prefix(8)) == [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        #expect(Array(bytes.suffix(8)) == [0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82])  // IEND and its CRC
        #expect(bytes == FakeThumbnails.fixturePNG(for: beach))
        #expect(await thumbnails.preview(for: dock) != bytes)
    }

    @Test func aPublishReadsBack() async throws {
        let thumbnails = FakeThumbnails()
        let beach = ref("Beach.design")
        #expect(await thumbnails.preview(for: beach) == nil)
        _ = try await thumbnails.publish(png: Data([1, 2, 3]), for: beach)
        #expect(await thumbnails.preview(for: beach) == Data([1, 2, 3]))
        #expect(await thumbnails.preview(for: ref("Other.design")) == nil)
    }

    @Test func unavailableHasNoPreview() async {
        let beach = ref("Beach.design")
        #expect(await FakeThumbnails(unavailable: "Not connected yet.", seeded: [beach]).preview(for: beach) == nil)
    }
}
