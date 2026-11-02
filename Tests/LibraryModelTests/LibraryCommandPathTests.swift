// LibraryCommandPathTests.swift (command-state CS-3, CS-5): the command each of Library's controls must run, so the
// window, the afterglow CLI and an agent take one path. One row per MenuCommand closure in LibraryCommands.swift (the
// 25 CS-3 moves), the Develop tab's Show Original (#3652), then CS-5's: the export sheet's controls (its Export runs
// `file.export` with the sheet's options), the browser's notice controls, Develop's Reset <slider> and the loupe's
// Grid. Fails when a listed id is missing from the catalog, has no params schema, can't run with no window, or a new
// spec's reason or params go astray. Linux-safe.
@testable import LibraryModel
import SuiteImaging
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
    ] + sheetControls + ToneSlider.develop.map { ("Develop > \($0.title) > Reset \($0.title)", LibraryCatalog.resetSliderID($0)) }

    /// CS-5's export sheet, browser and loupe controls. The sheet's 11 are these 10 and the name alert's Cancel,
    /// which only dismisses the alert (the lint's dismiss rule); the notice's button is one row per action.
    static let sheetControls: [(control: String, id: String)] = [
        ("Export > Choose…", "export.set-folder"), ("Export > Presets > <preset>", "export.apply-preset"),
        ("Export > Save as Preset…", "export.save-preset"), ("Export > Save as Preset… > Save", "export.save-preset"),
        ("Export > Cancel", "export.close"), ("Export > Export", "file.export"),
        ("Export > Exporting > Cancel", "export.cancel"), ("Export > Finished > Try Again", "export.retry"),
        ("Export > Finished > Show in Finder", "export.show-in-finder"), ("Export > Finished > Done", "export.close"),
        ("Notice > Show in Finder", "file.show-catalog"), ("Notice > Import Folder…", "file.import-folder"),
        ("Notice > Close", "notice.close"), ("Import Notice > Show", "notice.show-failures"),
        ("Import Notice > Close", "notice.close"), ("Loupe > Grid", "view.grid"),
    ]

    /// The catalog tests' states, plus the loupe at actual size, where Zoom to Fit can act.
    static var states: [(String, LibraryCatalog)] {
        let shared = LibraryCommandCatalogTests.states
        var zoomed = Dictionary(uniqueKeysWithValues: shared)["loupe"] ?? LibraryCatalog()
        zoomed.zoomLoupe(.actual)
        func with(_ name: String, _ change: (inout LibraryCatalog) -> Void) -> LibraryCatalog {
            var c = Dictionary(uniqueKeysWithValues: shared)[name] ?? LibraryCatalog(); change(&c); return c
        }
        let editing = with("two selected") { _ = $0.beginExport(folder: "/tmp/Exports") }
        var running = editing
        _ = running.exportPlan(existingNames: [])
        var failed = running
        failed.finishExport(ExportSummary(total: 2, written: ["IMG_0001.jpg"],
                                          failures: [FileFailure(path: "IMG_0002.jpg", reason: "Disk full.")], failedIDs: ["IMG_0002"]))
        return shared + [
            ("loupe at actual size", zoomed), ("export editing", editing), ("exporting", running), ("export failed", failed),
            ("damaged", with("empty") { $0.catalogState = .damaged }),
            ("import failures", with("grid") {
                $0.importNotice = ImportNotice(folder: "/shoot", added: 1, failures: [FileFailure(path: "/shoot/a.jpg", reason: "Not an image.")])
            }),
            ("cull error", with("grid") { $0.cullError = "Culling is off." }),
        ]
    }
    static func state(_ name: String) -> LibraryCatalog { Dictionary(uniqueKeysWithValues: states)[name] ?? LibraryCatalog() }

    @Test func everyControlIsListed() {
        #expect(Self.controls.count == 26 + 16 + ToneSlider.develop.count, "CS-3's 26, CS-5's 16 and a reset per slider")
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
            ("export.set-folder", Self.state("two selected"), "Choose File > Export… to open the export sheet."),
            ("export.set-folder", Self.state("exporting"), "The export is running."),
            ("export.apply-preset", Self.state("export editing"), nil),
            ("export.close", Self.state("two selected"), "The export sheet isn't open."),
            ("export.close", Self.state("exporting"), "The export is still running."),
            ("export.close", Self.state("export failed"), nil),
            ("export.cancel", Self.state("export editing"), "No export is running."),
            ("export.cancel", Self.state("exporting"), nil),
            ("export.retry", Self.state("export editing"), "No photos failed to export."),
            ("export.retry", Self.state("export failed"), nil),
            ("export.show-in-finder", Self.state("exporting"), "Nothing has been exported yet."),
            ("file.show-catalog", Self.state("grid"), "The catalog file isn't damaged."),
            ("file.show-catalog", Self.state("damaged"), nil),
            ("notice.close", Self.state("damaged"), "There is no notice to close."),
            ("notice.close", Self.state("cull error"), nil),
            ("notice.show-failures", Self.state("cull error"), "No files failed to import."),
            ("notice.show-failures", Self.state("import failures"), nil),
            ("photo.reset-contrast", Self.state("grid"), "Develop isn't connected yet."),
            ("photo.reset-contrast", Self.state("every slider"), nil),
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
        var e = Self.state("export editing")
        _ = try Self.catalog.run("export.set-folder", params: .object(["folder": .string("/web")]), on: &e)
        _ = try Self.catalog.run("export.apply-preset", params: .object([
            "name": .string("Web"), "quality": .number(70), "format": .string("PNG"), "sidecar": .bool(true),
        ]), on: &e)
        #expect(e.exportRun.options == ExportOptions(longEdge: nil, quality: 70, folder: "/web", format: .png, sidecar: true))
        _ = try Self.catalog.run("export.apply-preset", params: .object(["name": .string("Small")]), on: &e)
        #expect(e.exportRun.options == ExportOptions(longEdge: 1024, quality: 80, folder: "/web"))
        let saved = try Self.catalog.run("export.save-preset", params: .object(["name": .string("Mine")]), on: &e).result
        #expect(saved == (try JSONValue(encoding: ExportPreset(name: "Mine", options: ExportOptions(longEdge: 1024, quality: 80, folder: "/web")))))
        #expect(throws: CatalogError.self) { try Self.catalog.run("export.apply-preset", params: .object(["name": .string("Nope")]), on: &e) }
        // A blank name saves nothing, from the CLI too (#4673).
        for blank in ["", "   "] {
            #expect(throws: CatalogError.failed(id: "export.save-preset", message: "Name the preset.")) {
                try Self.catalog.run("export.save-preset", params: .object(["name": .string(blank)]), on: &e)
            }
        }
        var f = Self.state("export failed")
        #expect(try Self.catalog.run("export.retry", params: .object([:]), on: &f).result == .object(["photos": .number(1)]))
        #expect(f.exportState == .running(done: 0, total: 1))
        var r = Self.state("every slider")
        _ = try Self.catalog.run("photo.reset-tint", params: .object([:]), on: &r)
        #expect(r.items.first { $0.id == "IMG_0001" }?.develop.value(.tint) == 0)
        #expect(r.items.first { $0.id == "IMG_0001" }?.develop.value(.vibrance) == 1)
        #expect(r.history.top?.name == "Reset Tint")
    }

    /// Show Failures lists them, then hides them; Close shuts the notice the row shows.
    @Test func noticeControls() throws {
        var c = Self.state("import failures")
        _ = try Self.catalog.run("notice.show-failures", params: .object([:]), on: &c)
        #expect(c.showsImportFailures)
        _ = try Self.catalog.run("notice.show-failures", params: .object([:]), on: &c)
        #expect(!c.showsImportFailures)
        _ = try Self.catalog.run("notice.close", params: .object([:]), on: &c)
        #expect(c.importNotice == nil)
        var cull = Self.state("cull error")
        _ = try Self.catalog.run("notice.close", params: .object([:]), on: &cull)
        #expect(cull.cullError == nil)
        let listed = Set(Self.controls.map(\.id))
        for action in [LibraryNoticeContent.Action.showCatalogInFinder, .showFailures, .importFolder] {
            #expect(listed.contains(action.commandID), "the notice's \(action) runs an unlisted id")
        }
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
