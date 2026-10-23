// LiveTrashTests.swift: the live Trash (cull-finish DR-8). On macOS a
// scratch file moves to the Trash and back to its path, a missing file
// throws, and a put-back onto a taken path refuses and leaves both files. On
// Linux there is no Trash: the service says so and every call throws.
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
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("LiveTrashTests-" + UUID().uuidString)
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

@Test func theServiceSaysWhetherItCanRun() {
    #expect(LiveTrash.unavailable == trashReason.map { "\($0)" })
    if trashReason != nil {
        #expect(throws: LibraryError.self) { try LiveTrash().moveToTrash("/tmp/IMG_0002.jpg") }
        #expect(throws: LibraryError.self) { try LiveTrash().putBack("/tmp/.Trash/IMG_0002.jpg", to: "/tmp/IMG_0002.jpg") }
    }
}
