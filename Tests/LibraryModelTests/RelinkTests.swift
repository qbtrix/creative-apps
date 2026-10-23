// RelinkTests.swift (catalog-files LC-1 written, LC-6 on): Relink's rule over a moved folder. Locating one of 40
// missing photos relinks all 40 to the same names in the new folder; a same-name file of another size is left
// missing; a photo in a sibling folder whose path only shares a prefix ("/cards/shoot-b" against "/cards/shoot")
// is never matched; a photo outside the old folder stays as it is. Sizes come from a table, no disk. Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
@testable import LibraryModel
import Testing

@Suite struct RelinkTests {
    /// Missing photos named IMG_0001... under `folder`, id equal to path.
    static func missing(_ count: Int, in folder: String) -> [PhotoItem] {
        (1...count).map { n in
            let name = "IMG_" + String(repeating: "0", count: 4 - String(n).count) + String(n)
            let path = folder + "/" + name + ".jpg"
            return PhotoItem(id: path, name: name, captureDate: Date(timeIntervalSince1970: Double(n) * 60),
                             color: Color3(0.5, 0.5, 0.5), path: path, availability: .missing)
        }
    }
    /// Every file's size by name, the same under the old folder and the new one.
    static func sameSizes(_ path: String) -> Int? {
        let name = path.split(separator: "/").last.map(String.init) ?? ""
        return 1_000 + name.count + (Int(name.filter(\.isNumber)) ?? 0)
    }

    @Test(.disabled("waits on LC-6")) func relinkingOneRelinksTheWholeFolder() throws {
        let photos = Self.missing(40, in: "/cards/shoot")
        let located = try #require(photos.first)
        let map = CatalogFileRules.relinks(missing: photos, located: (id: located.id, file: "/moved/shoot/IMG_0001.jpg"),
                                           size: Self.sameSizes)
        #expect(map.count == 40)
        for photo in photos { #expect(map[photo.id] == "/moved/shoot/" + photo.name + ".jpg") }
    }

    @Test(.disabled("waits on LC-6")) func aSameNameFileOfAnotherSizeIsNotLinked() {
        let photos = Self.missing(3, in: "/cards/shoot")
        let size: (String) -> Int? = { $0 == "/moved/shoot/IMG_0002.jpg" ? 7 : Self.sameSizes($0) }
        let map = CatalogFileRules.relinks(missing: photos, located: (id: photos[0].id, file: "/moved/shoot/IMG_0001.jpg"),
                                           size: size)
        #expect(Set(map.keys) == [photos[0].id, photos[2].id])
        #expect(map[photos[1].id] == nil)
    }

    @Test(.disabled("waits on LC-6")) func aFolderThatOnlySharesAPrefixIsNotMatched() {
        let shoot = Self.missing(2, in: "/cards/shoot"), sibling = Self.missing(2, in: "/cards/shoot-b")
        let elsewhere = Self.missing(1, in: "/other")
        let map = CatalogFileRules.relinks(missing: shoot + sibling + elsewhere,
                                           located: (id: shoot[0].id, file: "/moved/shoot/IMG_0001.jpg"), size: Self.sameSizes)
        #expect(Set(map.keys) == Set(shoot.map(\.id)))
        #expect(map.values.allSatisfy { $0.hasPrefix("/moved/shoot/") })
    }

    @Test(.disabled("waits on LC-6")) func anUnknownSizeIsNotLinked() {
        let photos = Self.missing(2, in: "/cards/shoot")
        let map = CatalogFileRules.relinks(missing: photos, located: (id: photos[0].id, file: "/moved/shoot/IMG_0001.jpg"),
                                           size: { $0.hasSuffix("IMG_0002.jpg") ? nil : Self.sameSizes($0) })
        #expect(Set(map.keys) == [photos[0].id])
    }
}
