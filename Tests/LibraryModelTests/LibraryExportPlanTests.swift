// LibraryExportPlanTests.swift: EX-2, the live exporter. The plan fits the
// long edge and never enlarges; render decodes at full size, develops with
// the photo's settings on the source shrunk to the plan's scale, resizes to
// the plan, draws samples without a decode and passes decode errors through. EX-14: a cropped photo plans at its crop.
import CoreColor
import CoreRaster
import Foundation
import Testing

@testable import LibraryModel

/// Answers every path with flat bytes at `size` (fitted to `maxLongSide`),
/// or throws `error`. Records the long sides it was asked for.
private actor FlatDecoder: PhotoDecoding {
    let size: PixelSize
    let error: LibraryError?
    private(set) var asked: [Int?] = []
    init(size: PixelSize, error: LibraryError? = nil) { self.size = size; self.error = error }

    func scan(folder: String) async throws -> FolderScan { FolderScan(candidates: [], failures: []) }

    func decode(path: String, maxLongSide: Int?) async throws -> DisplayImage {
        asked.append(maxLongSide)
        if let error { throw error }
        let out = maxLongSide.map { size.fitting(longSide: $0) } ?? size
        guard let image = DisplayImage(size: out, rgba8: [UInt8](repeating: 120, count: out.width * out.height * 4))
        else { throw LibraryError.notAnImage(path) }
        return image
    }
}

/// Records the settings and buffer sizes it renders with and hands the buffer back.
private final class DevelopSpy: DevelopRendering, @unchecked Sendable {
    private let lock = NSLock()
    private var seen: [DevelopSettings] = []
    private var shapes: [PixelSize] = []
    var settings: [DevelopSettings] { lock.withLock { seen } }
    var sizes: [PixelSize] { lock.withLock { shapes } }
    func render(_ buffer: PixelBuffer, settings: DevelopSettings) throws -> PixelBuffer {
        lock.withLock { seen.append(settings); shapes.append(PixelSize(width: buffer.width, height: buffer.height)) }
        return buffer
    }
    func histogram(of buffer: PixelBuffer) throws -> HistogramBins { .empty }
}

private func photo(_ id: String, _ size: PixelSize, file: Bool = true,
                   develop: DevelopSettings = .neutral) -> PhotoItem {
    PhotoItem(id: id, name: id, captureDate: Date(timeIntervalSince1970: 0), color: Color3(0.2, 0.4, 0.6),
              path: file ? "/shoot/\(id).jpg" : nil, pixelSize: size, develop: develop)
}

@Suite struct LibraryExportPlanTests {
    func sizes(longEdge: Int?) -> [PixelSize] {
        let photos = LibraryFixtures.photos(named: "shoot")  // IMG_0003 is 4000 × 6000
        let exporter = LiveExporter(decoder: FakeDecoder(photos: []), develop: FakeDevelop())
        return exporter.plan([photos[0], photos[2]], options: ExportOptions(longEdge: longEdge, folder: "/out"),
                             existingNames: []).items.map(\.size)
    }

    @Test func planFitsTheLongEdgeAndNeverEnlarges() {
        #expect(sizes(longEdge: 1024) == [PixelSize(width: 1024, height: 683), PixelSize(width: 683, height: 1024)])
        let full = [PixelSize(width: 6000, height: 4000), PixelSize(width: 4000, height: 6000)]
        #expect(sizes(longEdge: 8192) == full)
        #expect(sizes(longEdge: nil) == full)
        #expect(LiveExporter.unavailable == nil)
    }

    /// EX-14: the plan sizes the crop, not the photo.
    @Test func planSizesTheCrop() throws {
        let full = PixelSize(width: 6000, height: 4000)
        let exporter = LiveExporter(decoder: FakeDecoder(photos: []), develop: FakeDevelop())
        func planned(_ crop: CropSettings) -> PixelSize? {
            let item = photo("c", full, develop: DevelopSettings.neutral.setting(crop: crop))
            return exporter.plan([item], options: ExportOptions(longEdge: 1024, folder: "/out"), existingNames: [])
                .items.first?.size
        }
        let square = try LiveCrop().initial(aspect: .square, angle: 0, photo: full)
        #expect(planned(square) == PixelSize(width: 1024, height: 1024))
        let straightened = try LiveCrop().initial(aspect: .threeTwo, angle: 2, photo: full)
        let frame = try LiveCrop().frame(straightened, photo: full)
        #expect(frame.width < 6000, "a 2° straighten trims the frame")
        #expect(planned(straightened) == PixelSize(width: frame.width, height: frame.height).fitting(longSide: 1024))
    }

    @Test func planNamesThroughTheSharedRule() {
        let photos = LibraryFixtures.photos(named: "shoot")
        let twice = [photos[0], photos[0]]
        let options = ExportOptions(folder: "/out", sidecar: true)
        let plan = LiveExporter(decoder: FakeDecoder(photos: []), develop: FakeDevelop())
            .plan(twice, options: options, existingNames: ["\(photos[0].name).jpg"])
        let rule = ExportNames.unique(stems: twice.map(\.name), format: .jpeg, sidecar: true,
                                      existing: ["\(photos[0].name).jpg"])
        #expect(plan.items.map(\.fileName) == rule)
        #expect(plan.items.map(\.photoID) == twice.map(\.id) && plan.options == options)
    }

    @Test func renderDecodesFullSizeDevelopsAndResizesToThePlan() async throws {
        let full = PixelSize(width: 400, height: 300)
        let decoder = FlatDecoder(size: full)
        let spy = DevelopSpy()
        let settings = DevelopSettings.neutral.setting(.exposure, to: 0.5)
        let item = photo("a", full, develop: settings)
        let exporter = LiveExporter(decoder: decoder, develop: spy)
        let planned = try #require(exporter.plan([item], options: ExportOptions(longEdge: 100, folder: "/out"),
                                                 existingNames: []).items.first)
        #expect(planned.size == PixelSize(width: 100, height: 75))
        let image = try await exporter.render(planned, photo: item)
        #expect(image.size == planned.size)
        #expect(image.rgba8.count == 100 * 75 * 4)
        #expect(await decoder.asked == [nil])
        #expect(spy.settings == [settings])
    }

    /// Quality gate #5953: develop runs on the export's pixels, shrunk before develop by the crop's scale.
    @Test func developRunsOnTheExportsPixelsNotTheCameras() async throws {
        let full = PixelSize(width: 600, height: 400)
        let spy = DevelopSpy()
        let exporter = LiveExporter(decoder: FlatDecoder(size: full), develop: spy)
        let plain = photo("a", full)
        let item = try #require(exporter.plan([plain], options: ExportOptions(longEdge: 200, folder: "/out"),
                                              existingNames: []).items.first)
        #expect(try await exporter.render(item, photo: plain).size == PixelSize(width: 200, height: 133))
        #expect(spy.sizes == [PixelSize(width: 200, height: 133)])
        // A square crop plans at 400 px, so the 600 px source shrinks by 200/400, not 200/600.
        let square = try LiveCrop().initial(aspect: .square, angle: 0, photo: full)
        let cropped = photo("b", full, develop: DevelopSettings.neutral.setting(crop: square))
        let cut = try #require(exporter.plan([cropped], options: ExportOptions(longEdge: 200, folder: "/out"),
                                             existingNames: []).items.first)
        _ = try await exporter.render(cut, photo: cropped)
        #expect(cut.size == PixelSize(width: 200, height: 200))
        #expect(spy.sizes.last == PixelSize(width: 300, height: 200))
    }

    @Test func sampleRendersFromSampleImageWithNoDecode() async throws {
        let size = PixelSize(width: 64, height: 48)
        let sample = photo("s", size, file: false)
        let decoder = FlatDecoder(size: size)
        let exporter = LiveExporter(decoder: decoder, develop: DevelopSpy())
        let item = ExportPlan.Item(photoID: "s", fileName: "s.jpg", size: size)
        let image = try await exporter.render(item, photo: sample)
        #expect(image == SampleImage.image(for: sample, longSide: nil))
        #expect(await decoder.asked.isEmpty)
    }

    @Test(arguments: [LibraryError.missingFile("/shoot/a.jpg"), LibraryError.notAnImage("/shoot/a.jpg")])
    func decodeErrorsPassThrough(_ error: LibraryError) async {
        let size = PixelSize(width: 40, height: 30)
        let exporter = LiveExporter(decoder: FlatDecoder(size: size, error: error), develop: DevelopSpy())
        let item = ExportPlan.Item(photoID: "a", fileName: "a.jpg", size: size)
        await #expect(throws: error) { try await exporter.render(item, photo: photo("a", size)) }
    }
}
