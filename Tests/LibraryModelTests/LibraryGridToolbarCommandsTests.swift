// LibraryGridToolbarCommandsTests.swift: the commands the grid's toolbar row
// calls (#3632) are catalog commands, so the CLI and MCP reach them too, and
// view.thumbnail-size sets the cell size, snapped to its step and clamped.
// Import Folder… and Export… are CS-3's specs, tested with them. Linux-safe.
@testable import LibraryModel
import SuiteKernel
import Testing

@Suite struct LibraryGridToolbarCommandsTests {
    static let catalog = LibraryCatalog.catalog

    static func samples() -> LibraryCatalog {
        var c = LibraryCatalog(services: .fake())
        c.loadSamples()
        return c
    }

    @Test func toolbarCommandsAreInTheCatalog() {
        for id in ["view.thumbnail-size", "view.sort", "file.import-folder", "file.export"] {
            #expect(Self.catalog.spec(id) != nil, "\(id) isn't a catalog command")
        }
    }

    @Test func thumbnailSizeSnapsAndClamps() throws {
        var c = Self.samples()
        _ = try Self.catalog.run("view.thumbnail-size", params: .object(["size": .number(240)]), on: &c)
        #expect(c.cellSize == 240)
        for (asked, set) in [(219, 200), (220, 240), (10, 80), (1000, 320)] {
            c.setCellSize(asked)
            #expect(c.cellSize == set, "\(asked) set \(c.cellSize)")
        }
        #expect(throws: CatalogError.self) {
            try Self.catalog.run("view.thumbnail-size", params: .object(["size": .number(1000)]), on: &c)
        }
    }
}
