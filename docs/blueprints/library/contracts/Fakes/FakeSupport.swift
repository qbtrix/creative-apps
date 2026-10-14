// Fakes/FakeSupport.swift: what every fake shares: the `-LibraryFakeMode`
// behavior (fail throws, slow waits 2 s first) and a gradient image made
// from a photo's sample color, so fake thumbnails and loupe pictures differ
// per photo and are the same on every run.
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

    /// A left-to-right gradient from the photo's color to black, `size` fitted to `longSide`.
    static func gradient(for photo: PhotoItem, longSide: Int?) -> DisplayImage? {
        let size = longSide.map { photo.pixelSize.fitting(longSide: $0) } ?? photo.pixelSize
        let color = photo.pixel
        var bytes = [UInt8]()
        bytes.reserveCapacity(size.width * size.height * 4)
        for _ in 0..<size.height {
            for x in 0..<size.width {
                let t = size.width > 1 ? Double(x) / Double(size.width - 1) : 0
                for channel in 0..<3 { bytes.append(UInt8((Double(color[channel]) * (1 - t / 2)).rounded())) }
                bytes.append(255)
            }
        }
        return DisplayImage(size: size, rgba8: bytes)
    }
}
