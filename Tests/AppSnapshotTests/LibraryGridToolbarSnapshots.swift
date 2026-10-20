// LibraryGridToolbarSnapshots.swift: the row over Library's grid (#3632) is
// built from catalog commands: each of its command ids is a Library catalog
// spec, Import Folder… and Export… are enabled exactly when their spec can
// run (else the spec's reason is the tooltip) and call the window's routes,
// and the row renders over the samples. CommandPathTests can't see a
// ToolbarAction, so this is what proves the wiring. Writes
// library-grid-toolbar-{light,dark}.png. macOS only.
import LibraryModel
import SuiteUI
import SwiftUI
import Testing

@testable import LibraryApp

@MainActor
@Suite struct LibraryGridToolbarSnapshots {
    static func samples(selecting ids: Set<String> = []) -> LibraryCatalog {
        var catalog = LibraryCatalog()
        catalog.loadSamples()
        catalog.select(ids)
        return catalog
    }

    @Test func everyControlIsACatalogCommand() {
        for id in LibraryGridToolbar.commandIDs {
            #expect(LibraryGridToolbar.spec(id) != nil, "\(id) isn't in Library's catalog")
        }
    }

    @Test func importAndExportFollowTheirSpecs() {
        var calls: [String] = []
        var menu = LibraryMenu()
        menu.file.importFolder = { calls.append("import") }
        menu.export.export = { calls.append("export") }
        let none = LibraryGridToolbar(model: Self.samples(), menu: menu)
        #expect(none.importAction.isEnabled && none.importAction.identifier == "library.grid.toolbar.import")
        #expect(none.exportAction.help == "Export…: Select a photo to export it.")
        let one = LibraryGridToolbar(model: Self.samples(selecting: ["IMG_0001"]), menu: menu)
        #expect(one.exportAction.isEnabled)
        one.importAction.perform()
        one.exportAction.perform()
        #expect(calls == ["import", "export"])
    }

    @Test func renders() throws {
        let toolbar = LibraryGridToolbar(model: Self.samples(selecting: ["IMG_0001"]))
        for scheme in [ColorScheme.light, .dark] {
            let suffix = scheme == .dark ? "dark" : "light"
            try snapshot(toolbar.frame(width: 1440, height: 900, alignment: .top), name: "library-grid-toolbar-\(suffix)", scheme: scheme)
        }
    }
}
