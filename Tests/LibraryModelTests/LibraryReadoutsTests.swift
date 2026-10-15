// LibraryReadoutsTests.swift: the accessibility values and help texts the
// Library window shows, all computed from the catalog's stored state
// (spine SP-13). Runs on Linux and macOS.
import CoreColor
@testable import LibraryModel
import Testing

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

private func photo(_ name: String, rating: Int = 0, picked: Bool = false, label: PhotoLabel? = nil,
                   availability: PhotoAvailability = .available) -> PhotoItem {
    PhotoItem(name: name, captureDate: Date(timeIntervalSince1970: 0), color: Color3(0.5, 0.25, 0.75),
              rating: rating, isFlagged: picked, label: label, availability: availability)
}

private func image(_ width: Int, _ height: Int) -> DisplayImage? {
    DisplayImage(size: PixelSize(width: width, height: height),
                 rgba8: [UInt8](repeating: 128, count: width * height * 4))
}

@Test func cellValueGoesFromLoadingToReadyWithTheCullSummary() {
    var catalog = LibraryCatalog()
    catalog.load([photo("a"), photo("b", rating: 3, picked: true, label: .red)])
    #expect(catalog.cellValue(for: "a") == "loading No stars")
    #expect(catalog.cellValue(for: "b") == "loading 3 stars, Picked, Red")
    catalog.thumbnails["b"] = image(256, 171)
    #expect(catalog.cellValue(for: "b") == "ready 256×171 3 stars, Picked, Red")
}

@Test func cellValueAndHelpSayAMissingFileIsUnreadable() {
    var catalog = LibraryCatalog()
    catalog.load([photo("gone", availability: .missing), photo("bad", availability: .unreadable("bad header"))])
    catalog.thumbnails["gone"] = image(4, 3)
    #expect(catalog.cellValue(for: "gone") == "unreadable No stars")
    #expect(catalog.cellHelp(for: "gone") == "The file is missing.")
    #expect(catalog.cellHelp(for: "bad") == "Library can't read this file: bad header.")
    #expect(catalog.cellHelp(for: "nobody") == nil)
}

@Test func loupeValueShowsQualitySizeChecksumZoomAndSummary() throws {
    var catalog = LibraryCatalog()
    catalog.load([photo("a", rating: 3)])
    #expect(catalog.loupeValue == nil)
    catalog.open("a")
    #expect(catalog.loupeValue == "loading fit 3 stars")
    let picture = try #require(image(4, 3))
    catalog.loupeRender = RenderedPhoto(image: picture, histogram: .empty, quality: .full)
    catalog.loupeZoom = .actual
    #expect(catalog.loupeValue == "full 4×3 100% 3 stars")
    catalog.showsTestValues = true
    #expect(picture.checksum.count == 16)
    #expect(catalog.loupeValue == "full 4×3 \(picture.checksum) 100% 3 stars")
    catalog.loupeRender?.quality = .preview
    catalog.loupeZoom = .scale(2.5)
    #expect(catalog.loupeValue == "preview 4×3 \(picture.checksum) 250% 3 stars")
}

@Test func loupeValueStartsUnreadableForAFileThatCannotBeRead() {
    var catalog = LibraryCatalog()
    catalog.load([photo("gone", availability: .missing)])
    catalog.open("gone")
    #expect(catalog.loupeValue == "unreadable fit No stars")
}

@Test func histogramValueIsTheChannelMeanAndNeverNaN() {
    #expect(LibraryCatalog.histogramValue(of: .empty) == "mean 0.0000")
    #expect(LibraryCatalog().histogramValue == "mean 0.0000")
    var white = Array(repeating: 0, count: HistogramBins.binCount)
    white[255] = 10
    var black = Array(repeating: 0, count: HistogramBins.binCount)
    black[0] = 10
    let bins = HistogramBins(red: white, green: white, blue: black, shadowClipped: 0, highlightClipped: 0)
    #expect(LibraryCatalog.histogramValue(of: bins) == "mean 0.6667")
}

@Test func catalogValueFlipsToDirtyWhenTheRevisionMoves() {
    var catalog = LibraryCatalog()
    #expect(catalog.catalogValue == "saved")
    catalog.saveRevision += 1
    #expect(catalog.catalogValue == "dirty")
    catalog.savedRevision = catalog.saveRevision
    #expect(catalog.catalogValue == "saved")
}

@Test func noticePrefersTheCatalogThenTheImportThenTheCull() {
    var catalog = LibraryCatalog()
    #expect(catalog.notice == nil)
    catalog.cullError = "Library couldn't change the rating."
    #expect(catalog.notice == LibraryNoticeContent(
        message: "Library couldn't change the rating.", isError: true, action: nil, source: .cull))
    let failure = FileFailure(path: "/Shoot/IMG_0001.jpg", reason: "bad header")
    catalog.importNotice = ImportNotice(folder: "Shoot", added: 2, failures: [failure])
    #expect(catalog.notice?.source == .import)
    #expect(catalog.notice?.isError == false)
    #expect(catalog.notice?.action == .showFailures)
    #expect(catalog.notice?.message == "Imported 2 photos. 1 file couldn't be imported.")
    catalog.catalogState = .damaged
    #expect(catalog.notice?.source == .catalog)
    #expect(catalog.notice?.isError == false)
    #expect(catalog.notice?.action == .showCatalogInFinder)
    #expect(catalog.notice?.message == CatalogFileState.damaged.message)
    catalog.catalogState = .newer(version: 2)
    #expect(catalog.notice?.source == .catalog && catalog.notice?.action == nil)
    #expect(catalog.notice?.isError == true)
}

@Test func damagedCatalogNoticeIsAWarningAndNewerIsAnError() {
    var catalog = LibraryCatalog()
    catalog.catalogState = .damaged
    #expect(catalog.notice?.isError == false)
    catalog.catalogState = .newer(version: 9)
    #expect(catalog.notice?.isError == true)
}

@Test func emptyStateSaysWhyImportCantActAndPointsToSamples() {
    let catalog = LibraryCatalog()
    let live = catalog.emptyState(importReason: nil)
    #expect(live == LibraryEmptyState(
        title: "No Photos", message: "Photos you import appear here, sorted by the date they were taken.",
        offersImport: true))
    let off = catalog.emptyState(importReason: "Import isn't connected yet (import).")
    #expect(off.title == "No Photos" && off.offersImport)
    #expect(off.message.contains("Import isn't connected yet (import)."))
    #expect(off.message.contains("File > Load Sample Photos"))
    #expect(catalog.emptyState(importReason: "No importer").message.hasPrefix("No importer. Choose"))
}

@Test func emptyStateAgreesWithTheCatalogNotice() {
    var catalog = LibraryCatalog()
    catalog.catalogState = .newer(version: 9)
    let newer = catalog.emptyState(importReason: "Import isn't connected yet (import).")
    #expect(newer.title != "No Photos" && !newer.offersImport)
    #expect(!newer.message.contains("import") && newer.message.contains("Update Library"))
    catalog.catalogState = .damaged
    let damaged = catalog.emptyState(importReason: nil)
    #expect(damaged.title != "No Photos" && damaged.offersImport)
    #expect(damaged.message.contains("catalog.json.bad"))
    #expect(catalog.emptyState(importReason: "Off.").message.contains("File > Load Sample Photos"))
}

@Test func photoCountTextHandlesTheSingular() {
    #expect(LibraryCatalog.photoCountText(0) == "0 photos")
    #expect(LibraryCatalog.photoCountText(1) == "1 photo")
    #expect(LibraryCatalog.photoCountText(60) == "60 photos")
}

@Test func helpForAMemberIsItsUnavailableReason() {
    var catalog = LibraryCatalog()
    #expect(catalog.help(for: "importer") == nil)
    catalog.services.unavailable["importer"] = "Import isn't connected yet (import)."
    #expect(catalog.help(for: "importer") == "Import isn't connected yet (import).")
}
