import Testing
import Foundation
import CoreColor
@testable import LibraryModel

@Test func fakesDriveEveryContract() async throws {
    let photo = PhotoItem(name: "IMG_1", captureDate: Date(timeIntervalSince1970: 0), color: Color3(1, 0, 0),
                          pixelSize: PixelSize(width: 6000, height: 4000))
    let services = LibraryServices.fake([photo])
    let result = try await services.importer.importFolder("/f", known: [], progress: { _ in })
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
