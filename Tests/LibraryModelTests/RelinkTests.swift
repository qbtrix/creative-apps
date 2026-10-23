// RelinkTests.swift (catalog-files LC-1 written, LC-6 on): locating one of 40 relinks all 40; another size is not
// linked; "/cards/shoot-b" never matches "/cards/shoot". Sizes come from a table, no disk. Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
@testable import LibraryModel
import SuiteKernel
import Testing

@Suite struct RelinkTests {
    /// Missing photos named IMG_0001... under `folder`, id equal to path.
    static func missing(_ count: Int, in folder: String) -> [PhotoItem] {
        (1...count).map { n in
            let name = "IMG_" + String(String(10_000 + n).dropFirst())
            return PhotoItem(id: folder + "/\(name).jpg", name: name, captureDate: Date(timeIntervalSince1970: Double(n) * 60),
                             color: Color3(0.5, 0.5, 0.5), path: folder + "/\(name).jpg", availability: .missing)
        }
    }
    /// Every file's size by name, the same under the old folder and the new one.
    static func sameSizes(_ path: String) -> Int? {
        let name = String(path.split(separator: "/").last ?? "")
        return 1_000 + name.count + (Int(name.filter(\.isNumber)) ?? 0)
    }

    @Test func relinkingOneRelinksTheWholeFolder() throws {
        let photos = Self.missing(40, in: "/cards/shoot")
        let located = try #require(photos.first)
        let map = CatalogFileRules.relinks(missing: photos, located: (id: located.id, file: "/moved/shoot/IMG_0001.jpg"),
                                           size: Self.sameSizes)
        #expect(map.count == 40)
        for photo in photos { #expect(map[photo.id] == "/moved/shoot/" + photo.name + ".jpg") }
    }

    @Test func aSameNameFileOfAnotherSizeIsNotLinked() {
        let photos = Self.missing(3, in: "/cards/shoot")
        let size: (String) -> Int? = { $0 == "/moved/shoot/IMG_0002.jpg" ? 7 : Self.sameSizes($0) }
        let map = CatalogFileRules.relinks(missing: photos, located: (id: photos[0].id, file: "/moved/shoot/IMG_0001.jpg"),
                                           size: size)
        #expect(Set(map.keys) == [photos[0].id, photos[2].id])
        #expect(map[photos[1].id] == nil)
    }

    @Test func aFolderThatOnlySharesAPrefixIsNotMatched() {
        let shoot = Self.missing(2, in: "/cards/shoot"), sibling = Self.missing(2, in: "/cards/shoot-b")
        let elsewhere = Self.missing(1, in: "/other")
        let map = CatalogFileRules.relinks(missing: shoot + sibling + elsewhere,
                                           located: (id: shoot[0].id, file: "/moved/shoot/IMG_0001.jpg"), size: Self.sameSizes)
        #expect(Set(map.keys) == Set(shoot.map(\.id)))
        #expect(map.values.allSatisfy { $0.hasPrefix("/moved/shoot/") })
    }

    /// Three photos whose files moved from `old/` to `new/` in a temp folder: Relink finds all three as one undo step.
    @Test func relinkCommandRelinksTheFolderInOneUndoStep() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("RelinkTests-\(UUID().uuidString)").path
        try FileManager.default.createDirectory(atPath: root + "/new", withIntermediateDirectories: true)
        let photos = Self.missing(3, in: root + "/old")
        for photo in photos { try Data("bytes".utf8).write(to: URL(fileURLWithPath: root + "/new/" + photo.name + ".jpg")) }
        var library = LibraryCatalog()
        library.load(photos)
        _ = try LibraryCatalog.catalog.run("photo.relink", params: .object(["id": .string(photos[0].id),
                                                                            "file": .string(root + "/new/IMG_0001.jpg")]), on: &library)
        #expect(library.items.map(\.path) == [root + "/new/IMG_0001.jpg", root + "/new/IMG_0002.jpg", root + "/new/IMG_0003.jpg"])
        #expect(library.items.allSatisfy { $0.availability == .available })
        #expect(library.undoTitle == "Undo Relink")
        library.undo()
        #expect(library.items == photos)
        #expect(throws: CatalogError.self) {
            try LibraryCatalog.catalog.run("photo.relink", params: .object(["id": .string(photos[0].id),
                                                                            "file": .string(root + "/gone.jpg")]), on: &library)
        }
    }
}
