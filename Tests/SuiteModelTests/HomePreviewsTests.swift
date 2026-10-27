// HomePreviewsTests.swift: the home's Recent card previews on FakeThumbnails
// (shared-thumbnails ST-3). Pictures are strings here; the app passes images.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteModel
import Testing

/// FakeThumbnails that records each `preview(for:)`.
actor CountingThumbnails: ThumbnailPublishing {
    let inner: FakeThumbnails
    private(set) var asked: [String] = []
    init(seeded: [SuiteDocumentRef]) { inner = FakeThumbnails(seeded: seeded) }
    func publish(png: Data, for ref: SuiteDocumentRef) async throws(SuiteError) -> String { try await inner.publish(png: png, for: ref) }
    func preview(for ref: SuiteDocumentRef) async -> Data? { asked.append(ref.fileID); return await inner.preview(for: ref) }
}

@MainActor @Suite struct HomePreviewsTests {
    let refs = [("Beach.ora", SuiteApp.photo), ("Logo.design", .design), ("Bounce.flare", .flare), ("Intro.halo", .halo)]
        .map { SuiteDocumentRef(path: "/fixture/\($0.0)", fileID: "id-\($0.0)", app: $0.1, type: SuiteTypeID(rawValue: "public.data"), displayName: $0.0) }

    /// "png:<bytes>" for a preview, "mark:<app>" for a mark.
    func previews() -> HomePreviews<String> { HomePreviews(decode: { "png:\($0.count)" }, mark: { "mark:\($0.rawValue)" }) }

    @Test func threePreviewsAndAMark() async {
        let previews = previews()
        await previews.load(refs, from: CountingThumbnails(seeded: Array(refs.prefix(3))))
        for ref in refs.prefix(3) {
            let bytes = FakeThumbnails.fixturePNG(for: ref).count
            #expect(previews.kind(for: ref) == .preview)
            // The published preview beats the recents' own thumbnail.
            #expect(previews.picture(for: ref, fallback: "own") == "png:\(bytes)")
        }
        #expect(previews.kind(for: refs[3]) == .mark)
        #expect(previews.picture(for: refs[3], fallback: nil) == "mark:halo")
    }

    @Test func eachDocumentIsAskedOnce() async {
        let thumbnails = CountingThumbnails(seeded: Array(refs.prefix(3)))
        let previews = previews()
        for _ in 0..<5 { await previews.load(refs, from: thumbnails) }
        await previews.load(Array(refs.reversed()), from: thumbnails)
        #expect(await thumbnails.asked == refs.map(\.fileID))
        #expect(previews.requests == refs.count)
    }

    @Test func aCardWaitsUntilItsAnswerIsIn() async {
        let previews = previews()
        #expect(previews.kind(for: refs[0]) == .waiting)
        #expect(previews.picture(for: refs[0], fallback: nil) == nil)
        await previews.load([refs[0]], from: CountingThumbnails(seeded: []))
        // Answered with nil: the recents' own thumbnail still wins over the mark.
        #expect(previews.picture(for: refs[0], fallback: "own") == "own")
        #expect(previews.picture(for: refs[0], fallback: nil) == "mark:photo")
    }

    @Test func unreadableBytesShowTheMarkDrawnOncePerApp() async {
        var drawn: [SuiteApp] = []
        let previews = HomePreviews<String>(decode: { _ in nil }, mark: { drawn.append($0); return $0.rawValue })
        await previews.load(refs, from: CountingThumbnails(seeded: refs))
        for _ in 0..<3 { for ref in refs { #expect(previews.picture(for: ref, fallback: nil) == ref.app.rawValue) } }
        #expect(refs.allSatisfy { previews.kind(for: $0) == .mark })
        #expect(drawn == refs.map(\.app))
    }
}
