// LibraryServicesTests.swift: `LibraryServices.fake` answers through every
// member, and `.live` names a reason for each spine stub (not the importer,
// live since IM-2) while the stubs still draw samples and apply the plain
// culling rules.
import CoreColor
import CoreRaster
import Foundation
import Testing

@testable import LibraryModel

/// A 24-photo shoot until SP-12 lands the `shoot` fixture; ids equal paths.
private func twentyFourPhotos() -> [PhotoItem] {
    (1...24).map { index in
        let name = String(format: "IMG_%04d", index)
        return PhotoItem(id: "/shoot/\(name).jpg", name: name, captureDate: Date(timeIntervalSince1970: Double(index)),
                         color: Color3(0.2, 0.4, 0.6), path: "/shoot/\(name).jpg",
                         pixelSize: PixelSize(width: 60, height: 40))
    }
}

private func liveServices() -> LibraryServices {
    LibraryServices.live(decoder: FakeDecoder(photos: []), writer: FakeJPEGWriter(), store: FakeCatalogStore())
}

@Test func everyFakeAnswers() async throws {
    let photos = twentyFourPhotos()
    let photo = try #require(photos.first)
    let services = LibraryServices.fake(photos)
    #expect(services.isPreview && services.unavailable.isEmpty)
    let scan = try await services.decoder.scan(folder: "/f")
    #expect(scan.candidates.count == 24)
    #expect(scan.candidates.first?.path == "/f/IMG_0001.jpg")
    let result = try await services.importer.importFolder("/f", known: [], progress: { _ in }, added: { _ in })
    #expect(result.added.count == 24)
    let decoded = try await services.decoder.decode(path: photo.id, maxLongSide: 30)
    #expect(decoded.size == PixelSize(width: 30, height: 20))
    let thumb = try await services.thumbnails.thumbnail(for: photo, longSide: 30)
    #expect(thumb.size == PixelSize(width: 30, height: 20))
    let rated = try services.culling.apply(.rating(2), to: [photo.id], in: photos)
    #expect(rated.first?.rating == 2)
    let data = try services.coding.encode(photos)
    #expect(try services.coding.decode(data).map(\.id) == photos.map(\.id))
    try await services.store.write(data)
    #expect(try await services.store.read() == data)
    #expect(try await services.store.setAside() == "catalog.json.bad")
    let loupe = try await services.loupe.render(photo, settings: .neutral, longSide: 60, quality: .full)
    #expect(loupe.image.size.longSide == 60)
    let buffer = try PixelBuffer(rgba8: decoded.rgba8, width: 30, height: 20)
    #expect(try services.develop.render(buffer, settings: .neutral) == buffer)
    let crop = try services.crop.initial(aspect: .square, angle: 0, photo: photo.pixelSize)
    #expect(abs(crop.rect.width - 40.0 / 60.0) < 1e-9)
    let plan = services.exporter.plan([photo], options: ExportOptions(longEdge: 16, folder: "/out"), existingNames: [])
    let item = try #require(plan.items.first)
    let image = try await services.exporter.render(item, photo: photo)
    try await services.writer.write(image, quality: 85, folder: "/out", fileName: item.fileName)
    #expect(try await services.writer.existingNames(in: "/out") == ["IMG_0001.jpg"])
    await #expect(throws: LibraryError.self) {
        try await services.writer.write(image, quality: 85, folder: "/out", fileName: item.fileName)
    }
}

@Test func liveListsAReasonForEveryStub() {
    let services = liveServices()
    #expect(!services.isPreview)
    let members = ["thumbnails", "coding", "develop", "crop", "exporter"]
    #expect(Set(services.unavailable.keys) == Set(members))
    #expect(services.unavailable.values.allSatisfy { !$0.isEmpty })
    let reasons: [String?] = [
        LiveThumbnails.unavailable, LiveCatalogCoding.unavailable,
        LiveDevelop.unavailable, LiveCrop.unavailable, LiveExporter.unavailable,
    ]
    #expect(reasons.allSatisfy { ($0?.isEmpty ?? true) == false })
    #expect(LiveImporter.unavailable == nil)
    #expect(LiveCulling.unavailable == nil)
    #expect(LiveLoupeImaging.unavailable == nil)
}

@Test func liveStubsDrawSamplesAndRefuseFiles() async throws {
    let sample = PhotoItem(name: "IMG_0001", captureDate: Date(timeIntervalSince1970: 0), color: Color3(1, 0, 0),
                           pixelSize: PixelSize(width: 40, height: 30))
    let live = liveServices()
    #expect(try await live.thumbnails.thumbnail(for: sample, longSide: 20).size == PixelSize(width: 20, height: 15))
    #expect(try await live.loupe.render(sample, settings: .neutral, longSide: 40, quality: .full).image.size.width == 40)
    #expect(try live.culling.apply(.rating(4), to: [sample.id], in: [sample]).first?.rating == 4)
    let file = try #require(twentyFourPhotos().first)
    let thumbReason = LibraryError.invalid(LiveThumbnails.unavailable ?? "")
    await #expect(throws: thumbReason) { try await live.thumbnails.thumbnail(for: file, longSide: 20) }
    // The loupe is live: a file goes to the decoder, which has no such photo.
    await #expect(throws: LibraryError.missingFile(file.path ?? "")) {
        try await live.loupe.render(file, settings: .neutral, longSide: 40, quality: .full)
    }
}

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
    let services = liveServices()
    #expect(services.unavailable["importer"] == nil && services.unavailable["culling"] == nil)
    #expect(services.unavailable.count == 5)
    // The importer is live: the fake decoder's empty folder has no photos.
    await #expect(throws: LibraryError.noPhotos("f")) {
        try await services.importer.importFolder("/f", known: [], progress: { _ in }, added: { _ in })
    }
    #expect(try services.develop.histogram(of: PixelBuffer(rgba8: [0, 0, 0, 255], width: 1, height: 1)) == .empty)
}
