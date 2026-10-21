// LibraryHistogramBudgetTests.swift: the histogram's render budget (#3633).
// The develop panel's histogram is counted once per loupe render, inside
// LiveLoupeImaging's actor (never on the main thread), from the pixels that
// render shows: a drag's 512 px preview, then the settled full render. The
// display shape (SuiteModel's ToneHistogram) is made there too, once, and
// carried on RenderedPhoto, so the window only reads it. A 120-sample Levels
// drag on a sample photo is 120 preview renders and must be 120 counts, none
// on the main thread, and every render's shape must match its counts. The
// count is deterministic, so it runs in the gate; the step time it prints
// (`LIBRARY-BUDGET develop histogram-drag`) is report-only. Linux and macOS.
import CoreColor
import CoreRaster
import Foundation
import SuiteModel
import Testing

@testable import LibraryModel

/// LiveDevelop that counts its histogram calls and the ones made on the main thread.
private final class CountingDevelop: DevelopRendering, @unchecked Sendable {
    private let live = LiveDevelop()
    private let lock = NSLock()
    private var counted = 0, onMain = 0
    var counts: (histograms: Int, onMain: Int) { lock.withLock { (counted, onMain) } }
    func render(_ buffer: PixelBuffer, settings: DevelopSettings) throws -> PixelBuffer {
        try live.render(buffer, settings: settings)
    }
    func histogram(of buffer: PixelBuffer) throws -> HistogramBins {
        let main = Thread.isMainThread
        lock.withLock { counted += 1; onMain += main ? 1 : 0 }
        return try live.histogram(of: buffer)
    }
}

@Test @MainActor func aLevelsDragCountsOneHistogramPerPreviewRenderOffTheMainThread() async throws {
    let develop = CountingDevelop()
    let loupe = LiveLoupeImaging(decoder: FakeDecoder(photos: []), develop: develop)
    let photo = PhotoItem(name: "IMG_0001", captureDate: Date(timeIntervalSince1970: 1), color: Color3(0.6, 0.4, 0.2),
                          path: nil, pixelSize: PixelSize(width: 4000, height: 3000))
    let clock = ContinuousClock()
    var last: RenderedPhoto?
    let elapsed = try await clock.measure {
        for sample in 1...120 {
            let levels = DevelopLevels.neutral.setting(.gamma, to: 1 + Double(sample) / 120)
            let settings = DevelopSettings.neutral.setting(levels: levels)
            last = try await loupe.render(photo, settings: settings, longSide: 2048, quality: .preview)
        }
    }
    #expect(develop.counts.histograms == 120)
    #expect(develop.counts.onMain == 0)
    let render = try #require(last)
    #expect(render.tone == ToneHistogram(
        channels: [render.histogram.red, render.histogram.green, render.histogram.blue],
        shadowClipped: render.histogram.shadowClipped, highlightClipped: render.histogram.highlightClipped))
    #expect(!render.tone.heights.isEmpty)
    print("LIBRARY-BUDGET develop histogram-drag total=\(elapsed) for 120 preview renders")
}
