// LibraryLiveLoupeTests.swift: LV-5. The live loupe decodes through
// PhotoDecoding, keeps the decodes of at most three photos (QB-LIB-8, model
// half), lets prefetch fill that cache, decodes previews at 512, draws
// samples from SampleImage and hands neutral settings back unchanged.
import Foundation
import Testing
import CoreColor
import CoreRaster

@testable import LibraryModel

/// Counts every decode and answers with a deterministic pattern at the
/// requested long side of a 400 x 300 file.
private actor CountingDecoder: PhotoDecoding {
    private(set) var decodes: [(path: String, maxLongSide: Int?)] = []
    func scan(folder: String) async throws -> FolderScan { FolderScan(candidates: [], failures: []) }
    func decode(path: String, maxLongSide: Int?) async throws -> DisplayImage {
        decodes.append((path, maxLongSide))
        let full = PixelSize(width: 400, height: 300)
        let size = maxLongSide.map { full.fitting(longSide: $0) } ?? full
        let seed = path.utf8.reduce(0) { ($0 &+ Int($1)) & 0xff }
        var bytes = [UInt8]()
        bytes.reserveCapacity(size.width * size.height * 4)
        for i in 0..<(size.width * size.height) {
            bytes += [UInt8((i + seed) & 0xff), UInt8((i * 3) & 0xff), UInt8(seed), 255]
        }
        guard let image = DisplayImage(size: size, rgba8: bytes) else { throw LibraryError.notAnImage(path) }
        return image
    }
}

/// Records each develop call; returns the buffer it was given.
private final class DevelopSpy: DevelopRendering, @unchecked Sendable {
    private let lock = NSLock()
    private var renders = 0, histograms = 0
    var counts: (renders: Int, histograms: Int) { lock.withLock { (renders, histograms) } }
    func render(_ buffer: PixelBuffer, settings: DevelopSettings) throws -> PixelBuffer {
        lock.withLock { renders += 1 }
        return buffer
    }
    func histogram(of buffer: PixelBuffer) throws -> HistogramBins {
        lock.withLock { histograms += 1 }
        var red = [Int](repeating: 0, count: HistogramBins.binCount)
        red[0] = buffer.width * buffer.height
        return HistogramBins(red: red, green: red, blue: red, shadowClipped: 0, highlightClipped: 0)
    }
}

private func photo(_ n: Int, path: Bool = true) -> PhotoItem {
    let name = "IMG_000\(n)"
    return PhotoItem(name: name, captureDate: Date(timeIntervalSince1970: Double(n)), color: Color3(0.6, 0.4, 0.2),
                     path: path ? "/shoot/\(name).jpg" : nil, pixelSize: PixelSize(width: 400, height: 300))
}

@Test func liveLoupeIsConnected() {
    #expect(LiveLoupeImaging.unavailable == nil)
}

@Test func holdsAtMostThreeBuffers() async throws {
    let decoder = CountingDecoder()
    let loupe = LiveLoupeImaging(decoder: decoder, develop: DevelopSpy())
    for n in 1...5 {
        _ = try await loupe.render(photo(n), settings: .neutral, longSide: 200, quality: .full)
        #expect(await loupe.cachedPhotoIDs.count <= 3)
    }
    #expect(await loupe.cachedPhotoIDs == [photo(3).id, photo(4).id, photo(5).id])
    #expect(await decoder.decodes.count == 5)
    // The newest three are cached: rendering one again decodes nothing; the evicted one decodes again.
    _ = try await loupe.render(photo(4), settings: .neutral, longSide: 200, quality: .full)
    #expect(await decoder.decodes.count == 5)
    _ = try await loupe.render(photo(1), settings: .neutral, longSide: 200, quality: .full)
    #expect(await decoder.decodes.count == 6)
    #expect(await loupe.cachedPhotoIDs == [photo(5).id, photo(4).id, photo(1).id])
}

@Test func prefetchFillsTheCacheSoTheNextRenderDecodesNothing() async throws {
    let decoder = CountingDecoder()
    let loupe = LiveLoupeImaging(decoder: decoder, develop: DevelopSpy())
    _ = try await loupe.render(photo(2), settings: .neutral, longSide: 200, quality: .full)
    await loupe.prefetch([photo(1), photo(3)], longSide: 200)
    #expect(await decoder.decodes.count == 3)
    let rendered = try await loupe.render(photo(3), settings: .neutral, longSide: 200, quality: .full)
    #expect(await decoder.decodes.count == 3)
    #expect(rendered.image.size == PixelSize(width: 200, height: 150))
    // Prefetching what is already cached decodes nothing either; samples are never decoded.
    await loupe.prefetch([photo(1), photo(3), photo(9, path: false)], longSide: 200)
    #expect(await decoder.decodes.count == 3)
    #expect(await loupe.cachedPhotoIDs.count == 3)
}

@Test func aNewScreenSizeDecodesAgain() async throws {
    let decoder = CountingDecoder()
    let loupe = LiveLoupeImaging(decoder: decoder, develop: DevelopSpy())
    _ = try await loupe.render(photo(1), settings: .neutral, longSide: 200, quality: .full)
    let larger = try await loupe.render(photo(1), settings: .neutral, longSide: 300, quality: .full)
    #expect(await decoder.decodes.map(\.maxLongSide) == [200, 300])
    #expect(larger.image.size == PixelSize(width: 300, height: 225))
}

@Test func previewDecodesAt512AndIsCachedApart() async throws {
    let decoder = CountingDecoder()
    let loupe = LiveLoupeImaging(decoder: decoder, develop: DevelopSpy())
    let preview = try await loupe.render(photo(1), settings: .neutral, longSide: 2000, quality: .preview)
    #expect(preview.quality == .preview)
    let full = try await loupe.render(photo(1), settings: .neutral, longSide: 2000, quality: .full)
    _ = try await loupe.render(photo(1), settings: .neutral, longSide: 2000, quality: .preview)
    let calls = await decoder.decodes
    #expect(calls.map(\.path) == [photo(1).path, photo(1).path])
    #expect(calls.map(\.maxLongSide) == [512, 2000])
    #expect(full.quality == .full)
    #expect(await loupe.cachedPhotoIDs == [photo(1).id])
}

@Test func aSampleIsDrawnFromSampleImageNeverDecoded() async throws {
    let decoder = CountingDecoder()
    let loupe = LiveLoupeImaging(decoder: decoder, develop: DevelopSpy())
    let sample = photo(1, path: false)
    let full = try await loupe.render(sample, settings: .neutral, longSide: 200, quality: .full)
    let preview = try await loupe.render(sample, settings: .neutral, longSide: 2000, quality: .preview)
    #expect(full.image == SampleImage.image(for: sample, longSide: 200))
    #expect(preview.image == SampleImage.image(for: sample, longSide: 512))
    #expect(await decoder.decodes.isEmpty)
    #expect(await loupe.cachedPhotoIDs.isEmpty)
}

@Test func neutralSettingsReturnTheDecodeUnchangedWithItsHistogram() async throws {
    let decoder = CountingDecoder()
    let develop = DevelopSpy()
    let loupe = LiveLoupeImaging(decoder: decoder, develop: develop)
    let rendered = try await loupe.render(photo(1), settings: .neutral, longSide: 200, quality: .full)
    let decoded = try await decoder.decode(path: photo(1).path ?? "", maxLongSide: 200)
    #expect(rendered.image == decoded)
    #expect(rendered.histogram.red[0] == 200 * 150)
    #expect(develop.counts.histograms == 1)
}

@Test func settingsGoThroughDevelop() async throws {
    let develop = DevelopSpy()
    let loupe = LiveLoupeImaging(decoder: CountingDecoder(), develop: develop)
    let lifted = DevelopSettings.neutral.setting(.exposure, to: 0.5)
    let rendered = try await loupe.render(photo(1), settings: lifted, longSide: 200, quality: .full)
    #expect(develop.counts.renders == 1)
    #expect(rendered.image.size == PixelSize(width: 200, height: 150))
}

@Test func aFailedDecodeThrowsAndCachesNothing() async throws {
    let loupe = LiveLoupeImaging(decoder: FakeDecoder(photos: []), develop: DevelopSpy())
    await #expect(throws: LibraryError.missingFile(photo(1).path ?? "")) {
        _ = try await loupe.render(photo(1), settings: .neutral, longSide: 200, quality: .full)
    }
    await loupe.prefetch([photo(2)], longSide: 200)
    #expect(await loupe.cachedPhotoIDs.isEmpty)
}

@Test func aDevelopFailureIsARenderFailure() async throws {
    let loupe = LiveLoupeImaging(decoder: CountingDecoder(), develop: FakeDevelop(mode: .fail))
    await #expect(throws: LibraryError.self) {
        _ = try await loupe.render(photo(1), settings: .neutral.setting(.exposure, to: 1), longSide: 200, quality: .full)
    }
}
