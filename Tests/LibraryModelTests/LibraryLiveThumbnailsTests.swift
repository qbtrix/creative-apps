// LibraryLiveThumbnailsTests.swift: TH-3. `LiveThumbnails` matches the
// hand-run pipeline (decode, develop, lanczos3) within QB-LIB-V5, keeps the
// photo's shape, draws samples from `SampleImage`, keeps its LRU under
// `ThumbnailBucket.cacheBytes` and decodes again after `invalidate`.
import CoreColor
import CoreRaster
import Foundation
import Testing

@testable import LibraryModel

/// A decoder that answers every path with one picture: a smooth gradient of
/// `size` (sampled at pixel centers, so a smaller decode is the same picture),
/// or flat bytes when `flat` (fast, for the cache test). Counts its calls.
private actor GradientDecoder: PhotoDecoding {
    let size: PixelSize
    let flat: Bool
    private(set) var calls = 0
    init(size: PixelSize, flat: Bool = false) { self.size = size; self.flat = flat }

    func scan(folder: String) async throws -> FolderScan { FolderScan(candidates: [], failures: []) }

    func decode(path: String, maxLongSide: Int?) async throws -> DisplayImage {
        calls += 1
        let out = maxLongSide.map { size.fitting(longSide: $0) } ?? size
        if flat {
            guard let image = DisplayImage(size: out, rgba8: [UInt8](repeating: 128, count: out.width * out.height * 4))
            else { throw LibraryError.notAnImage(path) }
            return image
        }
        var bytes = [UInt8]()
        bytes.reserveCapacity(out.width * out.height * 4)
        for y in 0..<out.height {
            let v = (Double(y) + 0.5) / Double(out.height)
            for x in 0..<out.width {
                let u = (Double(x) + 0.5) / Double(out.width)
                bytes += [UInt8((40 + 180 * u).rounded()), UInt8((220 - 160 * v).rounded()),
                          UInt8((60 + 90 * (u + v) / 2).rounded()), 255]
            }
        }
        guard let image = DisplayImage(size: out, rgba8: bytes) else { throw LibraryError.notAnImage(path) }
        return image
    }
}

private func filePhoto(_ id: String, _ size: PixelSize) -> PhotoItem {
    PhotoItem(id: id, name: id, captureDate: Date(timeIntervalSince1970: 0), color: Color3(0.2, 0.4, 0.6),
              path: "/shoot/\(id).jpg", pixelSize: size)
}

@Test func matchesFullPipeline() async throws {
    let full = PixelSize(width: 1200, height: 800)
    let decoder = GradientDecoder(size: full)
    let live = LiveThumbnails(decoder: decoder, develop: LiveDevelop())
    let thumb = try await live.thumbnail(for: filePhoto("a", full), longSide: 256)
    #expect(thumb.size == PixelSize(width: 256, height: 171))

    let decoded = try await decoder.decode(path: "a", maxLongSide: nil)
    var buffer = try PixelBuffer(rgba8: decoded.rgba8, width: 1200, height: 800, colorSpace: .sRGB)
    buffer = try LiveDevelop().render(buffer, settings: .neutral)
    let expected = try buffer.resized(width: 256, height: 171, filter: .lanczos3).rgba8(colorSpace: .sRGB)
    try #require(expected.count == thumb.rgba8.count)
    var total = 0, worst = 0
    for (a, b) in zip(thumb.rgba8, expected) {
        let difference = abs(Int(a) - Int(b))
        total += difference
        worst = max(worst, difference)
    }
    #expect(Double(total) / Double(expected.count) <= 1)
    #expect(worst <= 8)
}

@Test func portraitKeepsItsShape() async throws {
    let size = PixelSize(width: 800, height: 1200)
    let live = LiveThumbnails(decoder: GradientDecoder(size: size), develop: LiveDevelop())
    let thumb = try await live.thumbnail(for: filePhoto("p", size), longSide: 256)
    #expect(thumb.size == PixelSize(width: 171, height: 256))
}

@Test func sampleIsDrawnNotDecoded() async throws {
    let decoder = GradientDecoder(size: PixelSize(width: 10, height: 10))
    let live = LiveThumbnails(decoder: decoder, develop: LiveDevelop())
    let sample = PhotoItem(name: "IMG_0001", captureDate: Date(timeIntervalSince1970: 0), color: Color3(1, 0.5, 0),
                           pixelSize: PixelSize(width: 1200, height: 800))
    let thumb = try await live.thumbnail(for: sample, longSide: 256)
    #expect(thumb == SampleImage.image(for: sample, longSide: 256))
    #expect(await decoder.calls == 0)
}

@Test func cacheStaysUnderCap() async throws {
    let size = PixelSize(width: 1024, height: 683)
    let live = LiveThumbnails(decoder: GradientDecoder(size: size, flat: true), develop: LiveDevelop())
    for index in 0..<300 {
        _ = try await live.thumbnail(for: filePhoto("p\(index)", size), longSide: 1024)
        #expect(await live.cachedBytes <= ThumbnailBucket.cacheBytes)
    }
    #expect(await live.cachedBytes > ThumbnailBucket.cacheBytes - size.width * size.height * 4)
}

@Test func leastRecentlyUsedGoesFirst() async throws {
    let size = PixelSize(width: 10, height: 10)
    let decoder = GradientDecoder(size: size, flat: true)
    let live = LiveThumbnails(decoder: decoder, develop: LiveDevelop(), cacheLimit: 2 * 400)
    let a = filePhoto("a", size), b = filePhoto("b", size), c = filePhoto("c", size)
    _ = try await live.thumbnail(for: a, longSide: 128)
    _ = try await live.thumbnail(for: b, longSide: 128)
    _ = try await live.thumbnail(for: a, longSide: 128)  // a is now newer than b
    _ = try await live.thumbnail(for: c, longSide: 128)  // evicts b
    #expect(await decoder.calls == 3)
    _ = try await live.thumbnail(for: a, longSide: 128)
    #expect(await decoder.calls == 3)
    _ = try await live.thumbnail(for: b, longSide: 128)
    #expect(await decoder.calls == 4)
}

@Test func invalidateDecodesAgain() async throws {
    let size = PixelSize(width: 1200, height: 800)
    let decoder = GradientDecoder(size: size, flat: true)
    let live = LiveThumbnails(decoder: decoder, develop: LiveDevelop())
    let photo = filePhoto("a", size)
    _ = try await live.thumbnail(for: photo, longSide: 128)
    _ = try await live.thumbnail(for: photo, longSide: 128)
    #expect(await decoder.calls == 1)
    await live.invalidate("a")
    #expect(await live.cachedBytes == 0)
    _ = try await live.thumbnail(for: photo, longSide: 128)
    #expect(await decoder.calls == 2)
    _ = try await live.thumbnail(for: photo, longSide: 256)
    #expect(await decoder.calls == 3)
}

@Test func liveThumbnailsAreConnected() {
    #expect(LiveThumbnails.unavailable == nil)
}
