// LibraryLaunchTests.swift: the launch arguments of blueprint 4.1 parse, and
// the named fixtures have the shape and order the journeys rely on.
import Foundation
import Testing

@testable import LibraryModel

@Test func everyLaunchArgumentParses() {
    let launch = LibraryLaunch(arguments: [
        "/path/LibraryApp", "-NSDocumentRevisionsDebugMode", "YES",
        "-LibraryFixture", "shoot", "-LibraryCatalogDir", "/tmp/cat",
        "-LibraryImportFolder", "/tmp/in", "-LibraryImportOnLaunch",
        "-LibraryExportTo", "/tmp/out", "-LibraryFakeMode", "slow",
        "-LibraryPerfProbe", "-LibraryTestValues", "-LibraryReduceMotion",
        "-LibraryWindowSize", "1280x800",
    ])
    #expect(launch.fixture == "shoot")
    #expect(launch.catalogDir == "/tmp/cat")
    #expect(launch.importFolder == "/tmp/in")
    #expect(launch.importOnLaunch)
    #expect(launch.exportTo == "/tmp/out")
    #expect(launch.fakeMode == .slow)
    #expect(launch.perfProbe && launch.testValues && launch.reduceMotion)
    #expect(launch.windowSize == LibraryWindowSize(width: 1280, height: 800))
}

@Test func noArgumentsMeanTheDefaults() {
    let launch = LibraryLaunch(arguments: ["/path/LibraryApp"])
    #expect(launch == LibraryLaunch(arguments: []))
    #expect(launch.fixture == nil && launch.catalogDir == nil && launch.importFolder == nil)
    #expect(!launch.importOnLaunch && !launch.perfProbe && !launch.testValues && !launch.reduceMotion)
    #expect(launch.exportTo == nil && launch.fakeMode == .ok && launch.windowSize == nil)
    #expect(launch.initialPhotos.isEmpty)
    #expect(!launch.services(decoder: FakeDecoder(photos: []), writer: FakeJPEGWriter(),
                             store: FakeCatalogStore()).isPreview)
}

@Test func badValuesFallBack() {
    #expect(LibraryLaunch(arguments: ["-LibraryFakeMode", "bogus"]).fakeMode == .ok)
    #expect(LibraryLaunch(arguments: ["-LibraryFakeMode", "fail"]).fakeMode == .fail)
    for size in ["0x5", "5x0", "-3x4", "12", "x", "axb", "10x10x10"] {
        #expect(LibraryLaunch(arguments: ["-LibraryWindowSize", size]).windowSize == nil)
    }
    #expect(LibraryLaunch(arguments: ["-LibraryWindowSize", "1x1"]).windowSize == LibraryWindowSize(width: 1, height: 1))
    // A value flag with nothing after it is just absent.
    #expect(LibraryLaunch(arguments: ["-LibraryFixture"]).fixture == nil)
}

@Test func shootFixtureHasItsShapeAndOrder() throws {
    let shoot = LibraryFixtures.photos(named: "shoot")
    #expect(shoot.count == 24)
    #expect(Set(shoot.map(\.id)).count == 24)
    let portrait = shoot.filter { $0.pixelSize == PixelSize(width: 4000, height: 6000) }
    #expect(portrait.map(\.name) == stride(from: 3, through: 24, by: 3).map { String(format: "IMG_%04d", $0) })
    #expect(shoot.filter { $0.pixelSize == PixelSize(width: 6000, height: 4000) }.count == 16)
    let start = Date(timeIntervalSince1970: 1_780_308_000)  // 2026-06-01 10:00 UTC
    for (offset, photo) in shoot.enumerated() {
        let n = offset + 1
        #expect(photo.name == String(format: "IMG_%04d", n))
        #expect(photo.captureDate == start.addingTimeInterval(Double((7 * n) % 24) * 60))
        #expect(photo.rating == 0 && photo.flag == .none && photo.label == nil)
        #expect(photo.path == "/fixture/shoot/\(photo.name).jpg" && photo.id == photo.path)
    }
    let byDate = shoot.sorted { LibrarySort.captureDate.orders($0, before: $1) }
    let byName = shoot.sorted { LibrarySort.name.orders($0, before: $1) }
    #expect(byDate.first?.name == "IMG_0024")
    #expect(byName.first?.name == "IMG_0001")
}

@Test func shootUnimportedFakesTheFilesButStartsEmpty() async throws {
    let launch = LibraryLaunch(arguments: ["-LibraryFixture", "shoot-unimported"])
    #expect(launch.initialPhotos.isEmpty)
    let services = launch.services(decoder: FakeDecoder(photos: []), writer: FakeJPEGWriter(),
                                   store: FakeCatalogStore())
    #expect(services.isPreview)
    let scan = try await services.decoder.scan(folder: "/in")
    #expect(scan.candidates.count == 24)
    let result = try await services.importer.importFolder("/in", known: [], progress: { _ in }, added: { _ in })
    #expect(result.added.count == 24)
    #expect(result.added == LibraryFixtures.photos(named: "shoot"))
}

@Test func shootLaunchStartsWithTheShoot() {
    let launch = LibraryLaunch(arguments: ["-LibraryFixture", "shoot"])
    #expect(launch.initialPhotos == LibraryFixtures.photos(named: "shoot"))
}

@Test func largeFixtureHasTenThousandUniqueRecords() throws {
    let large = LibraryFixtures.photos(named: "large")
    #expect(large.count == 10_000)
    #expect(Set(large.map(\.id)).count == 10_000)
    #expect(large.first?.name == "IMG_00001" && large.last?.name == "IMG_10000")
    let first = try #require(large.first), last = try #require(large.last)
    let span = last.captureDate.timeIntervalSince(first.captureDate)
    #expect(span > 364 * 86_400 && span < 365 * 86_400)
}

@Test func samplesEmptyAndUnknownFixtures() {
    let samples = LibraryFixtures.photos(named: "samples")
    #expect(samples == LibrarySample.items())
    #expect(samples.count == 60)
    #expect(samples.allSatisfy { $0.pixelSize == PixelSize(width: 4032, height: 3024) && $0.path == nil })
    #expect(LibraryFixtures.photos(named: "empty").isEmpty)
    #expect(LibraryFixtures.photos(named: "nonsense").isEmpty)
    #expect(LibraryFixtures.photos(named: nil).isEmpty)
}

// MARK: LibraryCatalog(launch:services:), the window's catalog at launch (SA-2)

private func launchCatalog(_ arguments: [String]) -> LibraryCatalog {
    let launch = LibraryLaunch(arguments: arguments)
    return LibraryCatalog(
        launch: launch,
        services: launch.services(decoder: FakeDecoder(photos: []), writer: FakeJPEGWriter(), store: FakeCatalogStore()))
}

@Test func samplesFixtureLaunchesWithSixtyPreviewPhotos() {
    let catalog = launchCatalog(["/path/LibraryApp", "-LibraryFixture", "samples"])
    #expect(catalog.items.count == 60)
    #expect(catalog.items == LibraryFixtures.photos(named: "samples"))
    #expect(catalog.services.isPreview)
    #expect(catalog.mode == .grid && catalog.selection.isEmpty)
    #expect(catalog.sortedItems.count == 60)
    #expect(!catalog.showsTestValues)
}

@Test func testValuesFlagSetsShowsTestValues() {
    #expect(launchCatalog(["-LibraryTestValues"]).showsTestValues)
    #expect(launchCatalog(["-LibraryFixture", "shoot", "-LibraryTestValues"]).showsTestValues)
    #expect(!launchCatalog(["-LibraryFixture", "shoot"]).showsTestValues)
}

@Test func noFixtureLaunchesEmptyOnLiveServicesWithEveryReason() {
    let catalog = launchCatalog(["/path/LibraryApp"])
    #expect(catalog.isEmpty)
    #expect(!catalog.services.isPreview)
    let reasons: [String: String?] = [
        "importer": LiveImporter.unavailable, "thumbnails": LiveThumbnails.unavailable,
        "culling": LiveCulling.unavailable, "coding": LiveCatalogCoding.unavailable,
        "loupe": LiveLoupeImaging.unavailable, "develop": LiveDevelop.unavailable,
        "crop": LiveCrop.unavailable, "exporter": LiveExporter.unavailable,
    ]
    #expect(catalog.services.unavailable == reasons.compactMapValues { $0 })
    // Every other stored value is a fresh catalog's.
    #expect(catalog == LibraryCatalog())
}

@Test func shootUnimportedLaunchStartsEmptyOnFakes() {
    let catalog = launchCatalog(["-LibraryFixture", "shoot-unimported"])
    #expect(catalog.isEmpty)
    #expect(catalog.services.isPreview)
}
