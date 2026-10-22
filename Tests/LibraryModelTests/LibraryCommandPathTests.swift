// LibraryCommandPathTests.swift (command-state CS-3): the command each of Library's menu controls must run, so the
// menu, the afterglow CLI and an agent take one path. One row per MenuCommand closure in LibraryCommands.swift (the
// 25 the slice moves), plus the Develop tab's Show Original (#3652). Fails when a listed id is missing from the
// catalog, has no params schema, can't run with no window, or a new spec's reason or params go astray. Linux-safe.
@testable import LibraryModel
import SuiteKernel
import Testing

@Suite struct LibraryCommandPathTests {
    static let catalog = LibraryCatalog.catalog

    /// Each control, as "<menu> > <item>", and the id it runs.
    static let controls: [(control: String, id: String)] = [
        ("File > Import Folder…", "file.import-folder"), ("File > Load Sample Photos", "file.load-samples"),
        ("File > Export…", "file.export"),
        ("Edit > Undo", "edit.undo"), ("Edit > Redo", "edit.redo"),
        ("Edit > Select All", "edit.select-all"), ("Edit > Deselect", "edit.deselect"),
        ("View > Grid", "view.grid"), ("View > Loupe", "view.loupe"),
        ("View > Zoom In", "view.zoom-in"), ("View > Zoom Out", "view.zoom-out"),
        ("View > Zoom to Fit", "view.zoom-to-fit"), ("View > Actual Size", "view.actual-size"),
        ("View > Sort By > <order>", "view.sort"),
        ("Photo > Copy Settings", "photo.copy-settings"), ("Photo > Paste Settings", "photo.paste-settings"),
        ("Photo > Reset Develop", "photo.reset-develop"), ("Photo > Crop", "photo.crop"), ("Photo > Reset Crop", "photo.reset-crop"),
        ("Metadata > Set Rating > <stars>", "metadata.set-rating"),
        ("Metadata > Set Flag > Pick", "metadata.pick"), ("Metadata > Set Flag > Reject", "metadata.reject"),
        ("Metadata > Set Flag > Clear Flag", "metadata.clear-flag"),
        ("Metadata > Set Label > None", "metadata.set-label"), ("Metadata > Set Label > <color>", "metadata.set-label"),
        ("Develop > Show Original", "view.show-original"),
    ]

    /// The catalog tests' states, plus the loupe at actual size, where Zoom to Fit can act.
    static var states: [(String, LibraryCatalog)] {
        let shared = LibraryCommandCatalogTests.states
        var zoomed = Dictionary(uniqueKeysWithValues: shared)["loupe"] ?? LibraryCatalog()
        zoomed.zoomLoupe(.actual)
        return shared + [("loupe at actual size", zoomed)]
    }
    static func state(_ name: String) -> LibraryCatalog { Dictionary(uniqueKeysWithValues: states)[name] ?? LibraryCatalog() }

    @Test func everyControlIsListed() {
        #expect(Self.controls.count == 26, "the 25 menu closures and Show Original")
        #expect(Set(Self.controls.map(\.control)).count == Self.controls.count)
    }

    /// Every listed id is in the catalog with an object params schema.
    @Test func everyListedIDIsACommandWithASchema() {
        for (control, id) in Self.controls {
            let described = Self.catalog.describe(id)
            #expect(described != nil, "\(control) runs \(id), which isn't in Library's catalog")
            guard case .object(let schema)? = described?.params else { continue }
            #expect(schema["type"] == .string("object"), "\(id)'s params have no object schema")
        }
    }

    /// Every listed id runs its example with no window on some Library state where it is available.
    @Test func everyListedIDRunsHeadless() {
        for id in Set(Self.controls.map(\.id)) {
            let example = Self.catalog.spec(id)?.example ?? .object([:])
            let ran = Self.states.contains { _, c in
                var copy = c
                return Self.catalog.availability(id, on: c).why == nil && (try? Self.catalog.run(id, params: example, on: &copy)) != nil
            }
            #expect(ran, "\(id) never ran headless")
        }
    }

    /// Each new spec says why it can't run, and runs once it can.
    @Test func reasonWhenUnavailable() {
        var running = Self.state("grid")
        _ = running.beginImport()
        let cases: [(String, LibraryCatalog, String?)] = [
            ("view.show-original", Self.state("grid"), "Select a photo to develop it."),
            ("view.show-original", Self.state("two selected"), "Open a photo in the loupe to see its original."),
            ("view.show-original", Self.state("loupe"), nil),
            ("file.export", Self.state("grid"), "Select a photo to export it."),
            ("file.export", Self.state("two selected"), nil),
            ("file.import-folder", running, "An import is already running."),
            ("file.import-folder", Self.state("grid"), nil),
        ]
        for (id, c, why) in cases {
            #expect(Self.catalog.availability(id, on: c).why == why, "\(id)")
        }
        var off = LibraryServices.fake()
        off.unavailable = ["develop": "Develop is off."]
        var loupe = LibraryCatalog(services: off)
        loupe.loadSamples(); loupe.open("IMG_0003")
        #expect(Self.catalog.availability("view.show-original", on: loupe).why != nil)
    }

    /// Export… opens the sheet on the params' options; Import Folder… begins the import of the params' folder.
    @Test func paramsReachRun() throws {
        var c = Self.state("two selected")
        let params: JSONValue = .object([
            "folder": .string("/out"), "longEdge": .number(1024), "quality": .number(60), "format": .string("PNG"),
            "naming": .object(["template": .string("{name}-{seq}")]), "sidecar": .bool(true), "metadata": .string("none"),
        ])
        _ = try Self.catalog.run("file.export", params: params, on: &c)
        let options = ExportOptions(longEdge: 1024, quality: 60, folder: "/out", format: .png,
                                    naming: ExportNaming(template: "{name}-{seq}"), sidecar: true, metadata: .none)
        #expect(c.exportRun == .editing(options))
        var g = Self.state("grid")
        let result = try Self.catalog.run("file.import-folder", params: .object(["folder": .string("/shoot")]), on: &g).result
        #expect(result == .object(["folder": .string("/shoot")]))
        #expect(g.importHelp == "An import is already running.")
    }

    /// Show Original on, then off: the loupe's photo keeps its develop values and nothing is recorded.
    @Test func showOriginalToggles() throws {
        var c = Self.state("loupe")
        let before = c.items, steps = c.history.undo.count
        #expect(!c.showsOriginal)
        _ = try Self.catalog.run("view.show-original", params: .object([:]), on: &c)
        #expect(c.showsOriginal)
        _ = try Self.catalog.run("view.show-original", params: .object([:]), on: &c)
        #expect(!c.showsOriginal)
        #expect(c.items == before && c.history.undo.count == steps)
        _ = try Self.catalog.run("view.show-original", params: .object([:]), on: &c)
        c.open("IMG_0004")
        #expect(!c.showsOriginal, "stepping to another photo ends it")
    }
}
