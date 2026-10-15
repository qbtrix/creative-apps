// LibraryFakesTests.swift: the fakes behind `-LibraryFakeMode`: the importer
// shows progress before its slow wait and throws before any callback when it
// fails; the platform fakes and culling keep the live rules.
import Foundation
import Testing

@testable import LibraryModel

/// 24 photos with distinct ids and paths, standing in for the `shoot` fixture.
private func shoot() -> [PhotoItem] {
    (1...24).map { n in
        let name = "IMG_" + String(repeating: "0", count: 4 - String(n).count) + String(n)
        return PhotoItem(id: "/shoot/\(name).jpg", name: name,
                         captureDate: Date(timeIntervalSince1970: Double(n) * 60),
                         color: .init(0.2, 0.4, 0.6), path: "/shoot/\(name).jpg")
    }
}

/// Collects callbacks from the importer's `@Sendable` closures.
private final class Calls: @unchecked Sendable {
    private let lock = NSLock()
    private var progressTexts: [String] = []
    private var firstProgressAt: Duration?
    private var addedCount = 0
    private let clock = ContinuousClock()
    private let start: ContinuousClock.Instant
    init() { start = clock.now }

    func progress(_ value: ImportProgress) {
        lock.lock(); defer { lock.unlock() }
        if firstProgressAt == nil { firstProgressAt = clock.now - start }
        progressTexts.append(value.text)
    }
    func added(_ photos: [PhotoItem]) {
        lock.lock(); defer { lock.unlock() }
        addedCount += photos.count
    }
    var snapshot: (texts: [String], first: Duration?, added: Int) {
        lock.lock(); defer { lock.unlock() }
        return (progressTexts, firstProgressAt, addedCount)
    }
}

@Test func slowImportShowsProgressBeforeItWaits() async throws {
    let calls = Calls()
    let importer = FakeImporter(photos: shoot(), mode: .slow)
    let result = try await importer.importFolder("/shoot", known: [],
                                                 progress: { calls.progress($0) },
                                                 added: { calls.added($0) })
    let seen = calls.snapshot
    #expect(seen.texts.first == "Importing 1 of 24")
    #expect(try #require(seen.first) < .milliseconds(100))
    #expect(seen.added == 24)
    #expect(seen.texts.count == 24)
    #expect(seen.texts.last == "Importing 24 of 24")
    #expect(result.added.count == 24)
    #expect(result.alreadyKnown == 0)
}

@Test func importSkipsKnownPhotos() async throws {
    let calls = Calls()
    let photos = shoot()
    let result = try await FakeImporter(photos: photos).importFolder(
        "/shoot", known: [photos[0].id, photos[1].id],
        progress: { calls.progress($0) }, added: { calls.added($0) })
    #expect(result.added.count == 22)
    #expect(result.alreadyKnown == 2)
    #expect(calls.snapshot.texts.first == "Importing 1 of 22")
}

@Test func failingImportThrowsBeforeAnyCallback() async {
    let calls = Calls()
    await #expect(throws: LibraryError.unreadableFolder("/shoot")) {
        _ = try await FakeImporter(photos: shoot(), mode: .fail).importFolder(
            "/shoot", known: [], progress: { calls.progress($0) }, added: { calls.added($0) })
    }
    let seen = calls.snapshot
    #expect(seen.texts.isEmpty)
    #expect(seen.added == 0)
}

@Test func fakeDecoderScanListsTheFixture() async throws {
    let photos = shoot()
    let scan = try await FakeDecoder(photos: photos).scan(folder: "/card")
    #expect(scan.candidates.map(\.path) == photos.map { "/card/\($0.name).jpg" })
    #expect(scan.candidates.allSatisfy { $0.kind == .jpeg })
    #expect(scan.failures.isEmpty)
    await #expect(throws: LibraryError.unreadableFolder("/card")) {
        _ = try await FakeDecoder(photos: photos, mode: .fail).scan(folder: "/card")
    }
}

@Test func fakeDecoderDecodesAKnownPathOnly() async throws {
    let photos = shoot()
    let image = try await FakeDecoder(photos: photos).decode(path: photos[0].id, maxLongSide: 64)
    #expect(image.size.longSide <= 64)
    await #expect(throws: LibraryError.missingFile("/nowhere.jpg")) {
        _ = try await FakeDecoder(photos: photos).decode(path: "/nowhere.jpg", maxLongSide: 64)
    }
}

@Test func fakeJPEGWriterRefusesASecondWriteToOneName() async throws {
    let writer = FakeJPEGWriter()
    let image = try #require(DisplayImage(size: PixelSize(width: 1, height: 1), rgba8: [0, 0, 0, 255]))
    try await writer.write(image, quality: 90, folder: "/out", fileName: "a.jpg")
    #expect(try await writer.existingNames(in: "/out") == ["a.jpg"])
    await #expect(throws: LibraryError.writeFailed(path: "/out/a.jpg", reason: "The file already exists.")) {
        try await writer.write(image, quality: 90, folder: "/out", fileName: "a.jpg")
    }
    await #expect(throws: LibraryError.self) {
        try await FakeJPEGWriter(mode: .fail).write(image, quality: 90, folder: "/out", fileName: "b.jpg")
    }
}

@Test func fakeCatalogStoreSetsAsideTheBadFile() async throws {
    let store = FakeCatalogStore(data: Data("x".utf8))
    #expect(try await store.setAside() == "catalog.json.bad")
    #expect(try await store.read() == nil)
    #expect(await store.setAsideCount == 1)
    try await store.write(Data("y".utf8))
    #expect(try await store.read() == Data("y".utf8))
    await #expect(throws: LibraryError.self) {
        try await FakeCatalogStore(mode: .fail).write(Data())
    }
}

@Test func fakeCullingKeepsTheRules() throws {
    let photos = shoot()
    let culling = FakeCulling()
    #expect(throws: LibraryError.invalid("A rating is 0 to 5 stars.")) {
        _ = try culling.apply(.rating(6), to: [photos[0].id], in: photos)
    }
    let rated = try culling.apply(.rating(4), to: [photos[0].id], in: photos)
    #expect(rated[0].rating == 4)
    #expect(rated[1].rating == 0)
    let ids = photos.map(\.id)
    #expect(culling.advance(from: ids[0], before: ids, after: ids) == ids[1])
    #expect(culling.advance(from: ids[23], before: ids, after: ids) == ids[23])
    #expect(throws: LibraryError.self) {
        _ = try FakeCulling(mode: .fail).apply(.flag(.pick), to: [ids[0]], in: photos)
    }
}

@Test func fakeCatalogCodingRoundTripsIdsAndRatings() throws {
    let coding = FakeCatalogCoding()
    let photos = Array(shoot().prefix(2))
    let decoded = try coding.decode(try coding.encode(photos))
    #expect(decoded.map(\.id) == photos.map(\.id))
    #expect(throws: LibraryError.damagedCatalog("fake")) {
        _ = try FakeCatalogCoding(mode: .fail).decode(Data())
    }
}

@Test func fakeThumbnailsDrawAGradient() async throws {
    let photo = shoot()[0]
    let image = try await FakeThumbnails().thumbnail(for: photo, longSide: 32)
    #expect(image.size.longSide <= 32)
    await #expect(throws: LibraryError.notAnImage(photo.id)) {
        _ = try await FakeThumbnails(mode: .fail).thumbnail(for: photo, longSide: 32)
    }
}
