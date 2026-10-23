// LibraryTrashStubTests.swift: cull-finish DR-1's contract. FakeTrash moves
// and puts back in memory, the live stub refuses with its reason, and Delete
// Rejects is off with a reason until DR-6. Runs on Linux and macOS.
@testable import LibraryModel
import Testing

@Test func fakeTrashMovesAndPutsBack() throws {
    let trash = FakeTrash()
    let first = try trash.moveToTrash("/shoot/IMG_0001.jpg")
    let second = try trash.moveToTrash("/other/IMG_0001.jpg")
    #expect(first != second)
    #expect(trash.moved == [first: "/shoot/IMG_0001.jpg", second: "/other/IMG_0001.jpg"])
    try trash.putBack(first, to: "/shoot/IMG_0001.jpg")
    #expect(trash.moved == [second: "/other/IMG_0001.jpg"])
    #expect(throws: LibraryError.self) { try trash.putBack(first, to: "/shoot/IMG_0001.jpg") }
}

@Test func fakeTrashRefusesTheNamedPaths() {
    let trash = FakeTrash(failing: ["/shoot/IMG_0002.jpg"])
    #expect(throws: LibraryError.self) { try trash.moveToTrash("/shoot/IMG_0002.jpg") }
    #expect(trash.moved.isEmpty)
}

@Test func liveTrashStubRefusesWithItsReason() {
    #expect(LiveTrash.unavailable != nil)
    #expect(throws: LibraryError.self) { try LiveTrash().moveToTrash("/a.jpg") }
    let services = LibraryServices.live(decoder: FakeDecoder(photos: []), writer: FakeJPEGWriter(),
                                        store: FakeCatalogStore())
    #expect(services.unavailable["trash"] == LiveTrash.unavailable)
    #expect(services.trash is LiveTrash)
    #expect(LibraryServices.fake().trash is FakeTrash)
}

@Test func labelKeysAreSixToNine() {
    #expect(LibraryKey.labelKeys.map(\.label) == [.red, .yellow, .green, .blue])
    #expect(LibraryKey(character: "5") == .rating(5))
}

@Test func deleteRejectsIsOffWithAReasonUntilItsBody() {
    var photos = LibraryFixtures.shoot()
    for index in [1, 4, 7] { photos[index].flag = .reject }
    var catalog = LibraryCatalog(services: .fake(photos))
    catalog.load(photos)
    #expect(catalog.deleteRejectsTargets.map(\.name) == ["IMG_0002", "IMG_0005", "IMG_0008"])
    #expect(catalog.deleteRejectsTitle == "Delete 3 Rejected Photos…")
    #expect(catalog.deleteRejectsMessage == "Move 3 rejected photos to the Trash?")
    #expect(catalog.deleteRejectsHelp != nil)
    catalog.deleteRejects()
    #expect(catalog.items.count == 24)

    var none = LibraryCatalog(services: .fake())
    none.load(LibraryFixtures.shoot())
    #expect(none.deleteRejectsTargets.isEmpty)
    #expect(none.deleteRejectsHelp?.hasPrefix("No rejected photos in ") == true)
}
