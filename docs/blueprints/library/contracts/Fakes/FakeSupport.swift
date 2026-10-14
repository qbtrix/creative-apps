// Fakes/FakeSupport.swift: what every fake shares: the `-LibraryFakeMode`
// behavior (fail throws, slow waits 2 s first) and the photo's sample
// gradient, so fake thumbnails and loupe pictures differ per photo and are
// the same on every run.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

enum FakeBehavior {
    /// Waits in `.slow`, throws `error` in `.fail`.
    static func perform(_ mode: FakeMode, failing error: LibraryError) async throws {
        if mode == .slow { try await Task.sleep(nanoseconds: 2_000_000_000) }
        if mode == .fail { throw error }
    }

    /// The photo's sample gradient (`SampleImage`), so fakes and samples agree.
    static func gradient(for photo: PhotoItem, longSide: Int?) -> DisplayImage? {
        SampleImage.image(for: photo, longSide: longSide)
    }
}
