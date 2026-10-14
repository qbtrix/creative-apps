import Testing
import Foundation
import CoreColor
import CoreRaster
@testable import LibraryModel

@Test func fakesDriveEveryContract() async throws {
    let photo = PhotoItem(name: "IMG_1", captureDate: Date(timeIntervalSince1970: 0), color: Color3(1, 0, 0),
                          pixelSize: PixelSize(width: 6000, height: 4000))
    let services = LibraryServices.fake([photo])
    let result = try await services.importer.importFolder("/f", known: [], progress: { _ in }, added: { _ in })
    #expect(result.added.count == 1)
    let thumb = try await services.thumbnails.thumbnail(for: photo, longSide: 256)
    #expect(thumb.size == PixelSize(width: 256, height: 171))
    #expect(thumb.checksum.count == 16)
    let rated = try services.culling.apply(.rating(3), to: [photo.id], in: [photo])
    #expect(rated.first?.rating == 3)
    #expect(throws: LibraryError.self) { try services.culling.apply(.rating(6), to: [photo.id], in: [photo]) }
    let plan = services.exporter.plan([photo, photo], options: ExportOptions(longEdge: 2048, folder: "/out"), existingNames: ["IMG_1.jpg"])
    #expect(plan.items.map(\.fileName) == ["IMG_1 2.jpg", "IMG_1 3.jpg"])
    #expect(plan.items.first?.size == PixelSize(width: 2048, height: 1365))
    let crop = try services.crop.initial(aspect: .square, angle: 0, photo: photo.pixelSize)
    #expect(abs(crop.rect.width - 4000.0 / 6000.0) < 1e-9)
    #expect(DevelopSettings.neutral.setting(.exposure, to: .nan).isNeutral)
    #expect(DevelopSettings.neutral.setting(.contrast, to: 500).value(.contrast) == 100)
    #expect(HistogramBins.empty.heights.red.allSatisfy { $0 == 0 })
    let loupe = try await services.loupe.render(photo, settings: .neutral, longSide: 2048, quality: .full)
    #expect(loupe.image.size.longSide == 2048)
    #expect(PhotoFileKind.kind(forFileName: "a.JPG") == .jpeg && PhotoFileKind.kind(forFileName: ".heic") == nil)
}

@Test func liveStubsSayWhyUntilBuilt() async throws {
    let services = LibraryServices.live(decoder: FakeDecoder(photos: []), writer: FakeJPEGWriter(), store: FakeCatalogStore())
    #expect(services.unavailable["importer"] == "Import isn't connected yet (import).")
    #expect(services.unavailable.count == 8)
    await #expect(throws: LibraryError.self) { try await services.importer.importFolder("/f", known: [], progress: { _ in }, added: { _ in }) }
}

@Test func noticesSayExactlyWhatJourneysRead() {
    #expect(ImportNotice(folder: "/f", added: 26, failures: [FileFailure(path: "/f/b.jpg", reason: "not an image file")]).message
        == "Imported 26 photos. 1 file couldn't be imported.")
    #expect(ImportNotice(folder: "/f", alreadyKnown: 26).message == "No new photos in /f.")
    #expect(ImportNotice(folder: "/f", error: .unreadableFolder("/f")).message
        == "Library can't read /f. Check that you have access to it.")
    #expect(ExportSummary(total: 2, written: ["a", "b"]).message == "Exported 2 photos.")
    #expect(ExportSummary(total: 24, written: ["a"], cancelled: true).message == "Exported 1 of 24. Export was cancelled.")
    #expect(CatalogFileState.newer(version: 2).canSave == false && CatalogFileState.damaged.canSave)
    #expect(ThumbnailBucket.longSide(forCell: 320, scale: 2) == 1024)
    #expect(ThumbnailBucket.longSide(forCell: 80, scale: 1) == 128)
}

@Test func fakesShowEveryJourneyChange() async throws {
    let date = Date(timeIntervalSince1970: 0)
    var photo = PhotoItem(name: "IMG_0001", captureDate: date, color: Color3(0.5, 0.5, 0.5), rating: 3, flag: .reject,
                          pixelSize: PixelSize(width: 600, height: 400))
    #expect(photo.cullSummary == "3 stars, Rejected")
    let culling = FakeCulling()
    #expect(culling.advance(from: "a", before: ["a", "b"], after: ["a", "b"]) == "b")
    #expect(culling.advance(from: "b", before: ["a", "b"], after: ["a", "b"]) == "b")
    let loupe = FakeLoupe()
    let plain = try await loupe.render(photo, settings: .neutral, longSide: 300, quality: .full)
    let brighter = try await loupe.render(photo, settings: DevelopSettings.neutral.setting(.exposure, to: 1), longSide: 300, quality: .full)
    #expect(plain.image.checksum != brighter.image.checksum)
    #expect(plain.histogram.red.reduce(0, +) == 300 * 200)
    let crop = FakeCrop()
    let square = try crop.initial(aspect: .square, angle: 0, photo: photo.pixelSize)
    let turned = try crop.straightened(square, angle: 10, photo: photo.pixelSize)
    #expect(turned.rect.width < square.rect.width)
    photo.develop = DevelopSettings.neutral.setting(crop: square)
    let thumb = try await FakeThumbnails().thumbnail(for: photo, longSide: 128)
    #expect(thumb.size.width == thumb.size.height)
    let live = LibraryServices.live(decoder: FakeDecoder(photos: []), writer: FakeJPEGWriter(), store: FakeCatalogStore())
    #expect(try live.develop.histogram(of: PixelBuffer(rgba8: [0, 0, 0, 255], width: 1, height: 1)) == .empty)
}

@Test func everyFakeAnswers() async throws {
    let photo = PhotoItem(name: "IMG_0001", captureDate: Date(timeIntervalSince1970: 0), color: Color3(0.2, 0.4, 0.6),
                          pixelSize: PixelSize(width: 60, height: 40))
    let services = LibraryServices.fake([photo])
    let scan = try await services.decoder.scan(folder: "/f")
    #expect(scan.candidates.map(\.path) == ["/f/IMG_0001.jpg"])
    let decoded = try await services.decoder.decode(path: photo.id, maxLongSide: 30)
    #expect(decoded.size == PixelSize(width: 30, height: 20))
    let data = try services.coding.encode([photo])
    #expect(try services.coding.decode(data).map(\.id) == ["IMG_0001"])
    try await services.store.write(data)
    #expect(try await services.store.read() == data)
    #expect(try await services.store.setAside() == "catalog.json.bad")
    let buffer = try PixelBuffer(rgba8: decoded.rgba8, width: 30, height: 20)
    #expect(try services.develop.render(buffer, settings: .neutral) == buffer)
    let plan = services.exporter.plan([photo], options: ExportOptions(longEdge: 16, folder: "/out"), existingNames: [])
    let item = try #require(plan.items.first)
    let image = try await services.exporter.render(item, photo: photo)
    try await services.writer.write(image, quality: 85, folder: "/out", fileName: item.fileName)
    #expect(try await services.writer.existingNames(in: "/out") == ["IMG_0001.jpg"])
    await #expect(throws: LibraryError.self) {
        try await services.writer.write(image, quality: 85, folder: "/out", fileName: item.fileName)
    }
}

@Test func liveStubsKeepSamplesWorking() async throws {
    let sample = PhotoItem(name: "IMG_0001", captureDate: Date(timeIntervalSince1970: 0), color: Color3(1, 0, 0),
                           pixelSize: PixelSize(width: 40, height: 30))
    let live = LibraryServices.live(decoder: FakeDecoder(photos: []), writer: FakeJPEGWriter(), store: FakeCatalogStore())
    #expect(try await live.thumbnails.thumbnail(for: sample, longSide: 20).size == PixelSize(width: 20, height: 15))
    #expect(try await live.loupe.render(sample, settings: .neutral, longSide: 40, quality: .full).image.size.width == 40)
    #expect(try live.culling.apply(.rating(4), to: [sample.id], in: [sample]).first?.rating == 4)
}
