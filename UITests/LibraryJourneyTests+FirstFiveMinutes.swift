// LibraryJourneyTests+FirstFiveMinutes.swift: Library's "first five minutes"
// beta gate (Journey+FirstFive.swift has the rules). Three first-week tasks,
// one test each, as a new user does them with no help: import a folder of
// photos, rate and pick one, export it as a JPEG. Each starts from the
// toolbar's Import Folder… on a fresh catalog and profile, with the 24 JPEGs
// `LibraryFiles.writeShoot` writes; -LibraryImportFolder and -LibraryExportTo
// stand in for the folder panels. A test that fails on a missing or hidden
// entry point names its `finding` issue. Shots are `library-first5-<step>`.
import XCTest

final class LibraryFirstFiveJourneys: XCTestCase {
    /// Import Folder… in the toolbar: the grid shows the folder's 24 photos.
    @MainActor func testFirst5ImportFolder() throws {
        let library = try importShoot([])
        library.snap("first5-imported")
    }

    /// Metadata > Set Rating > 3 Stars and Set Flag > Pick on a clicked photo: its cell reads 3 stars, and
    /// the picks collection (whatever the catalog calls it, Favorites or Picks) counts one more photo.
    @MainActor func testFirst5RateAndPick() throws {
        let library = try importShoot([])
        let photo = cell("IMG_0001", library)
        photo.click()
        library.choose(menu: ["Metadata", "Set Rating", "3 Stars"], stuck: Self.stuckRate)
        XCTAssert(FirstFive.wait(5) { photo.label.localizedCaseInsensitiveContains("3 stars") }, "IMG_0001 reads \(photo.label), not 3 stars")
        let before = collectionCounts(library)
        library.choose(menu: ["Metadata", "Set Flag", "Pick"], stuck: Self.stuckRate)
        var after: [String: Int] = [:]
        let picked = FirstFive.wait(5) {
            after = self.collectionCounts(library)
            return after.contains { name, count in count == (before[name] ?? 0) + 1 }
        }
        XCTAssert(picked, "picking IMG_0001 added it to no collection: the sidebar read \(before), then \(after)")
        library.snap("first5-rated")
    }

    /// File > Export…, Export: a JPEG of the clicked photo at the sheet's long edge.
    @MainActor func testFirst5ExportJPEG() throws {
        let exports = FirstFive.folder("library-first5-exports")
        let library = try importShoot(["-LibraryExportTo", exports.path])
        cell("IMG_0001", library).click()
        library.choose(menu: ["File", "Export…"])
        let longEdge = library.element("library.export.longEdge")
        XCTAssert(longEdge.waitForExistence(timeout: 5), "the Export sheet shows no size")
        let edge = Int((longEdge.value as? String) ?? "") ?? 0
        library.snap("first5-export-sheet")
        library.reachable("Export", in: library.app.sheets.firstMatch).click()
        let written = try XCTUnwrap(FirstFive.file(in: exports, ext: "jpg"), "Export wrote no JPEG")
        XCTAssertEqual(Array(try Data(contentsOf: written).prefix(2)), [0xFF, 0xD8], "\(written.lastPathComponent) isn't a JPEG")
        let size = FirstFive.pixelSize(of: written)
        XCTAssertEqual(max(size?.width ?? 0, size?.height ?? 0), edge, "the JPEG is \(String(describing: size)), not \(edge) on its long edge")
    }

    /// Where a new user gets stuck, by finding issue.
    private static let stuckRate = "(first five minutes)"

    /// Library on a fresh catalog and profile after the toolbar's Import Folder… on the 24-photo shoot.
    @MainActor private func importShoot(_ arguments: [String]) throws -> Journey {
        let folder = try LibraryFiles.freshPhotoFolder(), catalog = try LibraryFiles.freshCatalogDir()
        addTeardownBlock { for url in [folder, catalog] { try? FileManager.default.removeItem(at: url) } }
        _ = try LibraryFiles.writeShoot(in: folder)
        let library = Journey("Library", self, arguments: arguments + FirstFive.freshProfile() + [
            "-LibraryImportFolder", folder.path, "-LibraryCatalogDir", catalog.path,
        ])
        library.timeBox()
        XCTAssert(library.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        library.reachable("Import Folder…").click()
        XCTAssert(library.element("library.import.notice").waitForExistence(timeout: 60), "Import Folder… imported nothing")
        XCTAssert(cell("IMG_0001", library).waitForExistence(timeout: 30), "the grid shows no imported photo")
        return library
    }

    /// Each sidebar collection's name and photo count, from one snapshot of the sidebar: a row's first
    /// non-number text is its name, its first number its count (0 when it shows none).
    @MainActor private func collectionCounts(_ library: Journey) -> [String: Int] {
        guard let sidebar = try? library.element("suite.sidebar").snapshot() else { return [:] }
        let rows: Set<XCUIElement.ElementType> = [.tableRow, .outlineRow, .cell]
        func texts(_ node: XCUIElementSnapshot) -> [String] {
            [node.label, node.value as? String ?? ""].filter { !$0.isEmpty } + node.children.flatMap { texts($0) }
        }
        var counts: [String: Int] = [:]
        func walk(_ node: XCUIElementSnapshot) {
            guard rows.contains(node.elementType) else { return node.children.forEach { walk($0) } }
            let words = texts(node)
            if let name = words.first(where: { Int($0) == nil }) { counts[name] = words.compactMap { Int($0) }.first ?? 0 }
        }
        walk(sidebar)
        return counts
    }

    /// The grid cell whose photo id names `name`.
    @MainActor private func cell(_ name: String, _ library: Journey) -> XCUIElement {
        library.app.descendants(matching: .any).matching(NSPredicate(
            format: "identifier BEGINSWITH %@ AND identifier CONTAINS %@", "library.grid.cell.", name)).firstMatch
    }
}
