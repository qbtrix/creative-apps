// Fakes/FakeSupport.swift: what every fake shares: the `-LibraryFakeMode`
// behavior (fail throws, slow waits 2 s first) and the photo's sample
// gradient, so fake thumbnails and loupe pictures differ per photo and are
// the same on every run. A turned photo's fakes stand as it faces.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel

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

    /// `photo` facing `facing` (its own orientation when nil), then at its crop's shape, so a turned or
    /// cropped photo looks turned or cropped on fakes too.
    static func cropShaped(_ photo: PhotoItem, _ crop: CropSettings?, facing: Orientation? = nil) -> PhotoItem {
        let side = (facing ?? photo.develop.orientation).size(photo.pixelSize.width, photo.pixelSize.height)
        guard crop != nil || side.width != photo.pixelSize.width else { return photo }
        let rect = crop?.rect ?? .full
        return photo.withSize(PixelSize(width: max(Int(Double(side.width) * rect.width), 1),
                                        height: max(Int(Double(side.height) * rect.height), 1)))
    }
}
