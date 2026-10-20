// LibraryCamerasFixtureTests.swift: the `cameras` fixture and MD-MJ1, the
// metadata-more contract walk (MD-3). The fixture is the shoot plus invented
// camera details and keywords, `IMG_0024` without any; a scan of it through
// `FakeDecoder` and `LiveImporter` keeps each photo's details; the fake
// sidecars write and read back, and fail in fail mode; `.live` without a
// writer says why sidecars are off. Runs on Linux and macOS.
import Foundation
@testable import LibraryModel
import Testing

private let cameras = LibraryFixtures.photos(named: "cameras")

private func fixturePhoto(_ n: Int) -> PhotoItem? {
    cameras.first { $0.name == "IMG_" + LibraryFixtures.padded(n, to: 4) }
}

private func launchCatalog(_ arguments: [String]) -> LibraryCatalog {
    let launch = LibraryLaunch(arguments: arguments)
    return LibraryCatalog(
        launch: launch,
        services: launch.services(decoder: FakeDecoder(photos: []), writer: FakeJPEGWriter(), store: FakeCatalogStore()))
}

/// Imports `/x` from the cameras fixture's fake decoder through the live importer.
private func importCameras() async throws -> ImportResult {
    let importer = LiveImporter(decoder: FakeDecoder(photos: cameras))
    return try await importer.importFolder("/x", known: [], progress: { _ in }, added: { _ in })
}

@Test func camerasFixtureIsTheShootWithCameraDetails() {
    let shoot = LibraryFixtures.photos(named: "shoot")
    #expect(cameras.count == 24)
    #expect(cameras.map(\.name) == shoot.map(\.name))
    #expect(cameras.map(\.captureDate) == shoot.map(\.captureDate))
    #expect(cameras.map(\.pixelSize) == shoot.map(\.pixelSize))
    #expect(cameras.map(\.id) == cameras.map { "/fixture/cameras/\($0.name).jpg" })
    #expect(cameras.filter { !$0.camera.isEmpty }.count == 23)
    #expect(fixturePhoto(24)?.camera == CameraDetails.none)
    // The shoot itself is unchanged: no details, no keywords.
    #expect(shoot.allSatisfy { $0.camera.isEmpty && $0.keywords.isEmpty })
}

@Test func camerasFixtureFollowsItsRules() throws {
    let lenses = [(lens: "100mm F2.8 Macro", f: 8.0), (lens: "24-70mm F2.8", f: 2.8), (lens: "50mm F1.8", f: 1.8)]
    let shutters = [1.0 / 2000, 1.0 / 500, 1.0 / 125, 1.0 / 30]
    for n in 1...23 {
        let camera = try #require(fixturePhoto(n)).camera
        #expect(camera.make == "Fixture Optics")
        #expect(camera.model == (n % 2 == 1 ? "FX-1" : "FX-2"))
        #expect(camera.lens == lenses[n % 3].lens && camera.fNumber == lenses[n % 3].f)
        let focal: Double = switch n % 3 { case 1: [24, 35, 50, 70][((n - 1) / 3) % 4]; case 2: 50; default: 100 }
        #expect(camera.focalLength == focal, "IMG_\(n)")
        #expect(camera.exposureTime == shutters[(n - 1) % 4])
        #expect(camera.iso == 100 << ((n - 1) % 7))
    }
    let byLens = Dictionary(grouping: cameras.compactMap(\.camera.lens), by: { $0 }).mapValues(\.count)
    #expect(byLens == ["24-70mm F2.8": 8, "50mm F1.8": 8, "100mm F2.8 Macro": 7])
    #expect(Set(cameras.compactMap(\.camera.iso)) == [100, 200, 400, 800, 1600, 3200, 6400])
}

@Test func camerasFixtureCarriesItsKeywords() throws {
    let keyed = cameras.filter { !$0.keywords.isEmpty }.map { "\($0.name): \($0.keywords.joined(separator: ","))" }
    #expect(keyed == [
        "IMG_0001: Beach", "IMG_0002: Beach", "IMG_0003: Beach,Sunset", "IMG_0004: Beach,Sunset",
        "IMG_0005: Sunset", "IMG_0006: Sunset", "IMG_0013: Beach", "IMG_0014: Beach", "IMG_0020: Summer",
    ])
    #expect(cameras.allSatisfy { $0.title.isEmpty && $0.caption.isEmpty })
}

@Test func camerasUnimportedStartsEmptyOnTheCamerasFakes() async throws {
    #expect(LibraryFixtures.photos(named: "cameras-unimported") == cameras)
    let catalog = launchCatalog(["-LibraryFixture", "cameras-unimported"])
    #expect(catalog.items.isEmpty && catalog.services.isPreview)
    let scan = try await catalog.services.decoder.scan(folder: "/x")
    #expect(scan.candidates.count == 24)
}

@Test func fakeDecoderScanCarriesEachPhotosCamera() async throws {
    let scan = try await FakeDecoder(photos: cameras).scan(folder: "/x")
    #expect(scan.candidates.map(\.camera) == cameras.map(\.camera))
    #expect(scan.candidates.map(\.path) == cameras.map { "/x/\($0.name).jpg" })
}

@Test func liveImporterKeepsEachCandidatesCamera() async throws {
    let result = try await importCameras()
    #expect(result.added.count == 24)
    let byName = Dictionary(uniqueKeysWithValues: cameras.map { ($0.name, $0.camera) })
    for photo in result.added { #expect(photo.camera == byName[photo.name], "\(photo.name)") }
    #expect(result.added.filter { !$0.camera.isEmpty }.count == 23)
}

/// MD-MJ1, steps 1–4.
@Test func testContractWalk() async throws {
    // 1. The cameras fixture launches with 24 photos, 23 with details.
    let catalog = launchCatalog(["-LibraryFixture", "cameras"])
    #expect(catalog.items.count == 24 && catalog.services.isPreview)
    #expect(catalog.items.filter { !$0.camera.isEmpty }.map(\.name) == (1...23).map { "IMG_" + LibraryFixtures.padded($0, to: 4) })
    let first = try #require(catalog.items.first { $0.name == "IMG_0001" })
    #expect(first.camera.make == "Fixture Optics" && first.camera.model == "FX-1")
    #expect(first.camera.lens == "24-70mm F2.8" && first.camera.iso == 100)
    #expect(catalog.items.first { $0.name == "IMG_0024" }?.camera == CameraDetails.none)

    // 2. Scanned and imported live, every photo keeps its fixture photo's details.
    let imported = try await importCameras()
    let fixtureCamera = Dictionary(uniqueKeysWithValues: catalog.items.map { ($0.name, $0.camera) })
    #expect(imported.added.count == 24)
    #expect(imported.added.allSatisfy { fixtureCamera[$0.name] == $0.camera })

    // 3. The fake sidecars write and read back; in fail mode the write throws.
    let bytes = Data("<x:xmpmeta/>".utf8)
    try await catalog.services.sidecars.write(bytes, sidecar: "/x/IMG_0001.xmp")
    #expect(try await catalog.services.sidecars.read(sidecar: "/x/IMG_0001.xmp") == bytes)
    let failing = launchCatalog(["-LibraryFixture", "cameras", "-LibraryFakeMode", "fail"])
    await #expect(throws: LibraryError.self) {
        try await failing.services.sidecars.write(bytes, sidecar: "/x/IMG_0001.xmp")
    }

    // 4. Live without a sidecar writer says why.
    let live = LibraryServices.live(decoder: FakeDecoder(photos: []), writer: FakeJPEGWriter(), store: FakeCatalogStore())
    #expect(live.unavailable["sidecars"] == "Writing sidecars isn't connected yet (metadata-more).")
}
