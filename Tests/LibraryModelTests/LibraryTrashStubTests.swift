// LibraryTrashStubTests.swift: cull-finish DR-1's contract. FakeTrash moves
// and puts back in memory, and Delete Rejects names its targets, on since
// DR-6. The live Trash (DR-8): on macOS a scratch file moves to the Trash and
// back, a missing file throws, and a put-back onto a taken path refuses and
// leaves both files; Linux has no Trash, so it is off with its reason and
// those three are skipped. Runs on Linux and macOS.
import Foundation
@testable import LibraryModel
import Testing

#if canImport(Darwin)
private let trashReason: Comment? = nil
#else
private let trashReason: Comment? = "Moving to the Trash needs macOS."
#endif

/// A fresh scratch folder holding `name` with `contents`; the file's path.
private func scratchFile(_ name: String, _ contents: String) throws -> String {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LiveTrash-" + UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    let file = folder.appendingPathComponent(name)
    try Data(contents.utf8).write(to: file)
    return file.path
}

@Test(.enabled(if: trashReason == nil, "Moving to the Trash needs macOS."))
func aFileMovesToTheTrashAndBack() throws {
    let path = try scratchFile("IMG_0002.jpg", "reject")
    let trashed = try LiveTrash().moveToTrash(path)
    #expect(!FileManager.default.fileExists(atPath: path))
    #expect(FileManager.default.fileExists(atPath: trashed), "moved, never deleted")
    #expect(trashed != path)
    try LiveTrash().putBack(trashed, to: path)
    #expect(FileManager.default.fileExists(atPath: path))
    #expect(!FileManager.default.fileExists(atPath: trashed))
    #expect(try String(contentsOfFile: path, encoding: .utf8) == "reject")
}

@Test(.enabled(if: trashReason == nil, "Moving to the Trash needs macOS."))
func aMissingFileThrows() throws {
    let path = try scratchFile("IMG_0005.jpg", "x") + ".gone"
    #expect(throws: LibraryError.self) { try LiveTrash().moveToTrash(path) }
}

@Test(.enabled(if: trashReason == nil, "Moving to the Trash needs macOS."))
func aTakenPathRefusesThePutBack() throws {
    let path = try scratchFile("IMG_0008.jpg", "reject")
    let trashed = try LiveTrash().moveToTrash(path)
    try Data("new".utf8).write(to: URL(fileURLWithPath: path))
    #expect(throws: LibraryError.self) { try LiveTrash().putBack(trashed, to: path) }
    #expect(try String(contentsOfFile: path, encoding: .utf8) == "new", "never put back over another file")
    #expect(FileManager.default.fileExists(atPath: trashed))
    try FileManager.default.moveItem(atPath: path, toPath: path + ".new")
    try LiveTrash().putBack(trashed, to: path)
    #expect(try String(contentsOfFile: path, encoding: .utf8) == "reject")
}

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

@Test func liveTrashIsOnWhereThereIsATrash() {
    #expect(LiveTrash.unavailable == trashReason.map { "\($0)" })
    #expect(throws: LibraryError.self) { try LiveTrash().moveToTrash("/no-such-folder/a.jpg") }
    if trashReason != nil {
        #expect(throws: LibraryError.self) { try LiveTrash().putBack("/tmp/.Trash/a.jpg", to: "/tmp/a.jpg") }
    }
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

@Test func deleteRejectsNamesItsTargets() {
    var photos = LibraryFixtures.shoot()
    for index in [1, 4, 7] { photos[index].flag = .reject }
    var catalog = LibraryCatalog(services: .fake(photos))
    catalog.load(photos)
    #expect(catalog.deleteRejectsTargets.map(\.name) == ["IMG_0002", "IMG_0005", "IMG_0008"])
    #expect(catalog.deleteRejectsTitle == "Delete 3 Rejected Photos…")
    #expect(catalog.deleteRejectsMessage == "Move 3 rejected photos to the Trash?")
    #expect(catalog.deleteRejectsHelp == nil)
    catalog.deleteRejects()
    #expect(catalog.items.count == 21)

    var none = LibraryCatalog(services: .fake())
    none.load(LibraryFixtures.shoot())
    #expect(none.deleteRejectsTargets.isEmpty)
    #expect(none.deleteRejectsHelp?.hasPrefix("No rejected photos in ") == true)
}
