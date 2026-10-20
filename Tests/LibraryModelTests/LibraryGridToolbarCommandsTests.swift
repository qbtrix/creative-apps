// LibraryGridToolbarCommandsTests.swift: the commands the grid's toolbar row
// calls (#3632) are catalog commands, so the CLI and MCP reach them too:
// view.thumbnail-size sets the cell size (snapped to its step and clamped),
// file.export opens the export sheet's state on the selection, and
// file.import says why it can't run with the importer's reason. Linux-safe.
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
        for id in ["view.thumbnail-size", "view.sort", "file.import", "file.export"] {
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

    @Test func exportOpensTheSheetOnTheSelection() throws {
        var c = Self.samples()
        #expect(Self.catalog.availability("file.export", on: c).why == "Select a photo to export it.")
        c.select(["IMG_0001"])
        _ = try Self.catalog.run("file.export", params: .object(["folder": .string("/tmp/Out")]), on: &c)
        #expect(c.exportState != .idle)
    }

    @Test func importSaysWhyItCantRun() throws {
        var services = LibraryServices.fake()
        services.unavailable = ["importer": "Import is off."]
        #expect(Self.catalog.availability("file.import", on: LibraryCatalog(services: services)).why == "Import is off.")
        #expect(Self.catalog.availability("file.import", on: Self.samples()).why == nil)
        #expect(LibraryHeadless.catalog.availability("file.import", on: try LibraryHeadless.new(.object([:]))).why
            == LibraryHeadless.fileCommandHelp)
    }
}
