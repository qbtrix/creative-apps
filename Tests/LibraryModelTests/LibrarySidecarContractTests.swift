// LibrarySidecarContractTests.swift: the sidecar contract (metadata-more
// MD-2). The fake writes and reads back bytes, fails in fail mode and refuses
// a foreign or non-sidecar path; `.live` without a writer names why sidecars
// can't be written and its default writer throws that sentence; a connected
// writer clears the reason; `SidecarFields` writes a reject as -1 (XMP
// Basic) and is empty only with nothing to say. Runs on Linux and macOS.
import CoreColor
import Foundation
@testable import LibraryModel
import Testing

private let epoch = Date(timeIntervalSince1970: 0)
private let bytes = Data("<x:xmpmeta/>".utf8)

private func photo(rating: Int = 0, flag: PhotoFlag = .none, label: PhotoLabel? = nil, keywords: [String] = [],
                   title: String = "", caption: String = "") -> PhotoItem {
    PhotoItem(id: "/x/IMG_0001.jpg", name: "IMG_0001", captureDate: epoch, color: Color3(0.2, 0.4, 0.6),
              rating: rating, label: label, flag: flag, path: "/x/IMG_0001.jpg", keywords: keywords,
              title: title, caption: caption)
}

/// A writer the window could pass: it only counts, so `.live` must take it as connected.
private struct ConnectedSidecars: SidecarWriting {
    func read(sidecar path: String) async throws -> Data? { nil }
    func write(_ data: Data, sidecar path: String) async throws {}
}

private func live(sidecars: (any SidecarWriting)? = nil) -> LibraryServices {
    guard let sidecars else {
        return .live(decoder: FakeDecoder(photos: []), writer: FakeJPEGWriter(), store: FakeCatalogStore())
    }
    return .live(decoder: FakeDecoder(photos: []), writer: FakeJPEGWriter(), store: FakeCatalogStore(),
                 sidecars: sidecars)
}

@Test func fakeWritesAndReadsBackBytes() async throws {
    let services = LibraryServices.fake()
    #expect(try await services.sidecars.read(sidecar: "/x/IMG_0001.xmp") == nil)
    try await services.sidecars.write(bytes, sidecar: "/x/IMG_0001.xmp")
    #expect(try await services.sidecars.read(sidecar: "/x/IMG_0001.xmp") == bytes)
    let replaced = Data("<x:xmpmeta>2</x:xmpmeta>".utf8)
    try await services.sidecars.write(replaced, sidecar: "/x/IMG_0001.xmp")
    #expect(try await services.sidecars.read(sidecar: "/x/IMG_0001.xmp") == replaced)
}

@Test func fakeFailModeThrowsReadOnly() async throws {
    let services = LibraryServices.fake(mode: .fail)
    await #expect(throws: LibraryError.writeFailed(path: "/x/IMG_0001.xmp", reason: "The folder is read-only.")) {
        try await services.sidecars.write(bytes, sidecar: "/x/IMG_0001.xmp")
    }
    #expect(try await services.sidecars.read(sidecar: "/x/IMG_0001.xmp") == nil)
}

@Test func fakeRefusesForeignAndNonSidecarPaths() async throws {
    let theirs = Data("<x:xmpmeta>theirs</x:xmpmeta>".utf8)
    let sidecars = FakeSidecars(files: ["/x/IMG_0002.xmp": theirs], foreign: ["/x/IMG_0002.xmp"])
    let foreign = "IMG_0002.xmp was written by another app; Library left it unchanged."
    await #expect(throws: LibraryError.writeFailed(path: "/x/IMG_0002.xmp", reason: foreign)) {
        try await sidecars.write(bytes, sidecar: "/x/IMG_0002.xmp")
    }
    #expect(try await sidecars.read(sidecar: "/x/IMG_0002.xmp") == theirs)
    for path in ["/x/IMG_0001.jpg", "/x/IMG_0001", "/x/IMG_0001.xmp.png"] {
        await #expect(throws: LibraryError.self) { try await sidecars.write(bytes, sidecar: path) }
        #expect(try await sidecars.read(sidecar: path) == nil)
    }
    #expect(await sidecars.files.keys.sorted() == ["/x/IMG_0002.xmp"])
}

@Test func liveWithoutWriterNamesWhySidecarsAreOff() async throws {
    #expect(UnconnectedSidecars.unavailable == "Writing sidecars isn't connected yet (metadata-more).")
    let services = live()
    #expect(services.unavailable["sidecars"] == UnconnectedSidecars.unavailable)
    #expect(services.sidecars is UnconnectedSidecars)
    await #expect(throws: LibraryError.invalid(UnconnectedSidecars.unavailable)) {
        try await UnconnectedSidecars().write(bytes, sidecar: "/x/IMG_0001.xmp")
    }
    await #expect(throws: LibraryError.invalid(UnconnectedSidecars.unavailable)) {
        try await services.sidecars.read(sidecar: "/x/IMG_0001.xmp")
    }
}

@Test func liveWithAWriterHasNoSidecarReason() {
    let services = live(sidecars: ConnectedSidecars())
    #expect(services.unavailable["sidecars"] == nil)
    #expect(services.sidecars is ConnectedSidecars)
    #expect(LibraryServices.fake().unavailable["sidecars"] == nil)
    #expect(LibraryServices.fake().sidecars is FakeSidecars)
}

@Test func launchPassesTheSidecarWriter() {
    let launch = LibraryLaunch(arguments: ["/path/LibraryApp"])
    let connected = launch.services(decoder: FakeDecoder(photos: []), writer: FakeJPEGWriter(),
                                    store: FakeCatalogStore(), sidecars: ConnectedSidecars())
    #expect(connected.sidecars is ConnectedSidecars && connected.unavailable["sidecars"] == nil)
    let unconnected = launch.services(decoder: FakeDecoder(photos: []), writer: FakeJPEGWriter(), store: FakeCatalogStore())
    #expect(unconnected.unavailable["sidecars"] == UnconnectedSidecars.unavailable)
    let fixture = LibraryLaunch(arguments: ["-LibraryFixture", "shoot"])
        .services(decoder: FakeDecoder(photos: []), writer: FakeJPEGWriter(), store: FakeCatalogStore(),
                  sidecars: ConnectedSidecars())
    #expect(fixture.sidecars is FakeSidecars && fixture.unavailable["sidecars"] == nil)
}

@Test func sidecarFieldsWriteARejectAsMinusOne() {
    #expect(SidecarFields(photo: photo(rating: 3, flag: .reject)).rating == -1)
    #expect(SidecarFields(photo: photo(rating: 3, flag: .pick)).rating == 3)
    #expect(SidecarFields(photo: photo(rating: 4)).rating == 4)
    let fields = SidecarFields(photo: photo(rating: 2, label: .blue, keywords: ["Beach", "Sunset"],
                                            title: "Dusk", caption: "Low tide"))
    #expect(fields.keywords == ["Beach", "Sunset"] && fields.title == "Dusk" && fields.caption == "Low tide")
    #expect(fields.rating == 2 && fields.label == .blue)
}

@Test func sidecarFieldsAreEmptyOnlyWithNothingToSay() {
    #expect(SidecarFields(photo: photo()).isEmpty)
    #expect(SidecarFields(photo: photo(flag: .pick)).isEmpty)
    #expect(!SidecarFields(photo: photo(flag: .reject)).isEmpty)
    #expect(!SidecarFields(photo: photo(rating: 1)).isEmpty)
    #expect(!SidecarFields(photo: photo(label: .red)).isEmpty)
    #expect(!SidecarFields(photo: photo(keywords: ["Beach"])).isEmpty)
    #expect(!SidecarFields(photo: photo(title: "Dusk")).isEmpty)
    #expect(!SidecarFields(photo: photo(caption: "Low tide")).isEmpty)
}

@Test func sidecarWriteCarriesItsPlan() {
    let fields = SidecarFields(photo: photo(rating: 5))
    let write = SidecarWrite(photoID: "/x/IMG_0001.jpg", path: "/x/IMG_0001.xmp", fields: fields, data: bytes)
    #expect(write.photoID == "/x/IMG_0001.jpg" && write.path == "/x/IMG_0001.xmp")
    #expect(write.fields == fields && write.data == bytes)
    #expect(write != SidecarWrite(photoID: "/x/IMG_0001.jpg", path: "/x/IMG_0001.xmp", fields: fields, data: Data()))
}
