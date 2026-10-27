// LibraryPasteboardAdapterTests.swift: clipboard-interop CB-11, turned on by CB-12 (packet
// docs/blueprints/suiteui/features/clipboard-interop.md, slice CB-library). Copy of the selected photo offers a
// full-size PNG with its develop settings applied, then a file URL, in the coder's order. Both come out of
// export's pipeline (`PhotoExporting.render`, the plan's `dropping`), so the copy is a clean export: the PNG
// is the developed pixels, and the file the URL names is written with the location properties left out.
//
// The PNG is made by `echo`, an encoder
// whose bytes spell out the size and checksum of the pixels it was given, so the picture can be read on Linux.
// That the coder hands a real PNG to Photo and Design as an image is SuitePasteboardCodingTests' (CB-3).
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
import SuiteKernel
import SuiteModel
import Testing

@testable import LibraryModel

/// A PNG "encoder" whose bytes are the pixels' size and checksum, so a test can tell which picture it got.
@Sendable private func echo(_ image: DisplayImage) -> Data {
    Data("\(image.size.width)x\(image.size.height) \(image.checksum)".utf8)
}

private let clipFolder = "/clip"

/// IMG_0001 at 60 × 40 (small, so the live develop runs fast), with `develop`.
private func photo(_ develop: DevelopSettings = .neutral) -> PhotoItem {
    PhotoItem(id: "/shoot/IMG_0001.jpg", name: "IMG_0001", captureDate: Date(timeIntervalSince1970: 1_780_308_000),
              color: Color3(0.5, 0.5, 0.5), path: "/shoot/IMG_0001.jpg",
              pixelSize: PixelSize(width: 60, height: 40), develop: develop)
}

/// A catalog holding `item` on fakes, but exporting through the live exporter and develop, with it selected.
private func catalog(_ item: PhotoItem, selected: Bool = true) -> LibraryCatalog {
    var services = LibraryServices.fake([item])
    services.exporter = LiveExporter(decoder: FakeDecoder(photos: [item]), develop: LiveDevelop())
    var catalog = LibraryCatalog(services: services)
    catalog.load([item])
    if selected { catalog.select([item.id]) }
    return catalog
}

private func copied(_ item: PhotoItem) async throws -> [TypedData] {
    try await LibraryPasteboardAdapter(encode: echo).copy(catalog(item), folder: clipFolder)
}

/// What export's pipeline renders for `item` at full size, echoed: what the copy's PNG must be.
private func exported(_ item: PhotoItem) async throws -> Data {
    let exporter = LiveExporter(decoder: FakeDecoder(photos: [item]), develop: LiveDevelop())
    let plan = exporter.plan([item], options: ExportOptions(longEdge: nil, folder: clipFolder, format: .png),
                             existingNames: [])
    let planned = try #require(plan.items.first)
    return echo(try await exporter.render(planned, photo: item))
}

@Suite struct LibraryPasteboardAdapterTests {
    /// The copy offers a PNG, then a file URL, and nothing else.
    @Test func copyOffersPngThenFileURL() async throws {
        let offered = try await copied(photo())
        #expect(offered.map(\.type) == [.png, .fileURL])
    }

    /// Mutation `.copiesDeveloped`: exposure +1 copies as the developed pixels at full size, never the original.
    @Test func pngIsTheDevelopedPhotoAtFullSize() async throws {
        let brighter = photo(DevelopSettings.neutral.setting(.exposure, to: 1))
        let png = try #require(try await copied(brighter).first { $0.type == .png })
        let text = String(decoding: png.data, as: UTF8.self)
        #expect(text.hasPrefix("60x40 "), "the PNG isn't the photo's full size: \(text)")
        let developed = try await exported(brighter), original = try await exported(photo())
        #expect(developed != original, "exposure +1 changed nothing, so this test proves nothing")
        #expect(png.data == developed, "the PNG isn't what export renders for the photo")
        #expect(png.data != original, "the PNG is the undeveloped original")
    }

    /// Mutation `.stripsLocation`: the file URL names a copy written by the writer without the location
    /// properties, never the original file (which may carry GPS).
    @Test func fileURLIsACleanCopyWithoutLocation() async throws {
        let item = photo()
        let library = catalog(item)
        let writer = try #require(library.services.writer as? FakeJPEGWriter)
        let offered = try await LibraryPasteboardAdapter(encode: echo).copy(library, folder: clipFolder)
        let url = try #require(offered.first { $0.type == .fileURL })
        let text = String(decoding: url.data, as: UTF8.self)
        #expect(text.hasPrefix("file://\(clipFolder)/"), "the URL isn't in the copy's folder: \(text)")
        #expect(text.hasSuffix(".png"), "the URL doesn't name a PNG: \(text)")
        #expect(text != "file://" + (item.path ?? ""), "the URL names the original file")
        let path = String(text.dropFirst("file://".count))
        let written = await writer.dropped
        let dropped = try #require(written[path], "the writer wrote no \(path)")
        #expect(dropped.isSuperset(of: ExportRules.dropped(.noLocation).properties), "the copy keeps location")
        #expect(dropped.contains("{GPS}"))
    }

    /// With nothing selected, Copy offers nothing and writes no file.
    @Test func nothingSelectedCopiesNothing() async throws {
        let library = catalog(photo(), selected: false)
        let writer = try #require(library.services.writer as? FakeJPEGWriter)
        let offered = try await LibraryPasteboardAdapter(encode: echo).copy(library, folder: clipFolder)
        let files = await writer.files
        #expect(offered.isEmpty)
        #expect(files.isEmpty)
    }
}
