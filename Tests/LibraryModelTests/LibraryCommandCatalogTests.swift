// LibraryCommandCatalogTests.swift (adopt-command-catalog AC-l2): Library's catalog keeps the catalog's laws on
// Library's states, keeps its ledger, each command's availability is the reason today's menu shows, and the menu
// table is unchanged. Fails when a reason changes, an edit records no step, or an id goes missing. Linux-safe.
import Foundation
@testable import LibraryModel
import SuiteImaging
import SuiteKernel
import Testing

/// The catalog as a headless document, so CatalogConformance can walk Library's catalog on any state:
/// each spec runs through `LibraryCatalog.catalog`, and save() is the catalog file's bytes.
struct LibraryCatalogDoc: HeadlessDocument {
    var catalog: LibraryCatalog
    static let app = "library", openExtensions: [String] = [], exportFormats: [String] = []
    static let catalog: CommandCatalog<LibraryCatalogDoc> =
        (try? CommandCatalog(app: app, LibraryCatalog.commands.map(lift), history: { LibraryCatalogSteps(catalog: $0.catalog) }))
        ?? .empty(app: app)
    static func lift(_ spec: CommandSpec<LibraryCatalog>) -> CommandSpec<LibraryCatalogDoc> {
        .typed(spec.id, title: spec.title, summary: spec.summary, kind: spec.kind, params: JSONValue.self, schema: spec.params,
               result: spec.result, example: spec.example, availability: { spec.availability($0.catalog) }
        ) { doc, params in try LibraryCatalog.catalog.run(spec.id, params: params, on: &doc.catalog).result }
    }
    static func open(_ data: Data, name: String) throws -> Self { throw CatalogError.notBuilt(id: "open", feature: "AC-l3") }
    static func new(_ options: JSONValue) throws -> Self { Self(catalog: LibraryCatalog(services: .fake())) }
    func save() throws -> Data { try LiveCatalogCoding().encode(catalog.items) }
    func export(_ format: String, options: JSONValue) throws -> [ExportedFile] { [] }
    func summary() -> JSONValue { .object([:]) }
}

@Suite struct LibraryCommandCatalogTests {
    static let catalog = LibraryCatalog.catalog

    /// Library's states: no photos, the samples with none, two, and two culled and developed photos selected, an
    /// edit and an undone edit, the loupe with copied settings on a cropped photo, and a crop draft open.
    static var states: [(String, LibraryCatalog)] {
        func with(_ base: LibraryCatalog, _ change: (inout LibraryCatalog) -> Void) -> LibraryCatalog {
            var catalog = base; change(&catalog); return catalog
        }
        let grid = with(LibraryCatalog(services: .fake())) { $0.loadSamples() }
        let two = with(grid) { $0.select(["IMG_0001", "IMG_0002"]) }
        let culled = with(two) {
            $0.setFlag(.pick); $0.setRating(2); $0.setLabel(.red)
            $0.setDevelop(.exposure, to: 1, coalesceKey: nil); $0.endCoalescing()
        }
        let loupe = with(culled) {
            $0.select(["IMG_0001"]); $0.copySettings(); $0.open("IMG_0003")
            $0.toggleCrop(); $0.setCropAngle(5); $0.toggleCrop()
        }
        return [
            ("empty", LibraryCatalog(services: .fake())), ("grid", grid), ("two selected", two), ("culled", culled),
            ("undone", with(culled) { $0.undo() }), ("loupe", loupe),
            ("cropping", with(loupe) { $0.toggleCrop(); $0.setCropAngle(-3) }),
            ("black & white", with(two) { $0.setKinds([.blackAndWhite(.neutral)], name: "Black & White") }),  // AJ-10: {} removes it
            ("every slider", with(two) { c in  // CS-5: each Reset <slider> has a value to reset
                for slider in ToneSlider.develop { c.setDevelop(slider, to: 1, coalesceKey: nil); c.endCoalescing() }
            }),
        ]
    }

    /// The reason each id's menu item showed before the catalog: AC-l1's `help(_:)` where the item runs an action,
    /// else the window's enablement with the menu's reason (the services' own first).
    static func oldHelp(_ id: String, _ c: LibraryCatalog) -> String?? {
        func menu(_ on: Bool, _ member: String, _ fallback: String) -> String? { on ? nil : c.services.unavailable[member] ?? fallback }
        let actions: [String: LibraryAction] = [
            "edit.undo": .undo, "edit.redo": .redo, "edit.select-all": .selectAll, "edit.select": .selectAll,
            "edit.deselect": .deselect, "file.load-samples": .loadSamples, "view.grid": .showGrid, "view.loupe": .showLoupe,
            "view.zoom-in": .zoomIn(fitScale: 1), "view.zoom-out": .zoomOut(fitScale: 1), "view.zoom-to-fit": .zoomToFit,
            "view.actual-size": .actualSize, "view.sort": .setSort(.name), "metadata.set-rating": .setRating(3),
            "metadata.pick": .setFlag(.pick), "metadata.reject": .setFlag(.reject), "metadata.clear-flag": .setFlag(.none),
            "metadata.set-label": .setLabel(.red), "metadata.auto-advance": .toggleAutoAdvance,
            "view.thumbnail-size": .setCellSize(160),
        ]
        if let action = actions[id] { return .some(c.help(action)) }
        return switch id {
        case "photo.copy-settings": .some(menu(c.canCopySettings, "develop", "Develop isn't connected yet."))
        case "photo.paste-settings": .some(menu(c.canPasteSettings, "develop", "Develop isn't connected yet."))
        case "photo.reset-develop": .some(menu(c.canEditDevelop, "develop", "Develop isn't connected yet."))
        case "photo.crop": .some(menu(c.cropHelp == nil, "crop", "Crop isn't connected yet."))
        case "photo.reset-crop": .some(menu(c.resetCropHelp == nil, "crop", "Crop isn't connected yet."))
        case "file.import-folder": .some(c.importHelp)  // CS-3: the window's enablement and reasons
        case "file.export": .some(c.exportHelp)
        case "export.set-folder", "export.apply-preset", "export.save-preset": .some(c.exportEditingHelp)  // CS-5
        case "export.close": .some(c.exportCloseHelp)
        case "export.cancel": .some(c.exportState.isRunning ? nil : "No export is running.")
        case "export.retry": .some(c.exportFinished?.failedIDs.isEmpty == false ? nil : "No photos failed to export.")
        case "export.show-in-finder": .some(c.exportFinished == nil ? "Nothing has been exported yet." : nil)
        case "file.show-catalog": .some(c.catalogState == .damaged ? nil : "The catalog file isn't damaged.")
        case "notice.close": .some(c.notice?.source == .import || c.notice?.source == .cull ? nil : "There is no notice to close.")
        case "notice.show-failures": .some(c.notice?.source == .import && c.importNotice?.failures.isEmpty == false ? nil : "No files failed to import.")
        case let id where ToneSlider.develop.map(LibraryCatalog.resetSliderID).contains(id):
            .some(menu(c.canEditDevelop, "develop", "Develop isn't connected yet."))
        case "view.show-original": .some(c.services.unavailable["develop"] ?? c.developHelp
            ?? (c.canShowOriginal ? nil : "Open a photo in the loupe to see its original."))
        case "image.rotate-cw", "image.rotate-ccw", "image.rotate-180", "image.flip":  // OC-8: the develop settings' reason
            .some(c.services.unavailable["develop"] ?? c.developHelp)
        case "crop.set-aspect", "crop.swap", "crop.set-frame", "crop.apply", "crop.reset": .some(c.cropHelp)
        case "file.recent", "file.open-recent", "file.drop": .some(nil)
        case "file.clear-recent": .some("No Recent Files")
        case "file.open-in": .some(c.openInHelp)
        case "file.share-prepare": .some(c.shareHelp)
        case "edit.copy": .some(c.copyHelp)
        case "catalog.backups": .some(nil)
        case "catalog.restore-backup": .some(c.importState != .idle ? LibraryBackups.importing
                                             : c.backup.backups == nil ? LibraryBackups.noBackups : nil)
        case "thumbnails.stats": .some(c.thumbnailDisk == nil ? "Thumbnails aren't kept on disk yet." : nil)
        case "adjust.black-and-white", "adjust.invert", "look.apply", "photo.set-develop": .some(c.services.unavailable["develop"] ?? c.developHelp)
        case let id where id.hasPrefix("filter."): .some(c.services.unavailable["develop"] ?? c.developHelp ?? LibraryCatalog.filtersInPhoto)
        case "look.list", "look.save", "look.delete": .some(nil)
        case "folders.list", "view.show-folder": .some(c.items.contains { $0.path?.hasPrefix("/") == true } ? nil : LibraryCatalog.noFolders)
        default: nil
        }
    }

    @Test func availabilityMatchesHelp() {
        var services = LibraryServices.fake()
        services.unavailable = ["develop": "Develop is off.", "crop": "Crop is off.", "culling": "Culling is off."]
        var off = LibraryCatalog(services: services)
        off.loadSamples(); off.select(["IMG_0001"])
        for id in Self.catalog.ids {
            #expect(Self.oldHelp(id, LibraryCatalog()) != nil, "\(id) has no old help to match")
            for (state, c) in Self.states + [("services off", off)] {
                #expect(Self.catalog.availability(id, on: c).why == Self.oldHelp(id, c) ?? nil, "\(id) on \(state)")
            }
        }
    }

    /// Quality gate #5953: a script sets a develop slider. One drag token is one undo step; Library's missing sliders refuse.
    @Test func setDevelopSetsTheTargetsSlider() throws {
        var c = Dictionary(uniqueKeysWithValues: Self.states)["two selected"] ?? LibraryCatalog()
        let steps = c.history.undo.count
        func set(_ slider: String, _ value: Double, drag: String? = nil) throws -> JSONValue? {
            try Self.catalog.run("photo.set-develop", params: .object(["slider": .string(slider), "value": .number(value),
                                                                       "drag": drag.map(JSONValue.string) ?? .null]), on: &c).result
        }
        #expect(try set("vibrance", 50) == .object(["vibrance": .number(50)]))
        #expect(c.items.filter { c.selection.contains($0.id) }.map(\.develop.vibrance) == [50, 50])
        #expect(c.history.undo.count == steps + 1)
        _ = try set("saturation", -20, drag: "d1"); _ = try set("saturation", -40, drag: "d1")
        #expect(c.history.undo.count == steps + 2, "one drag is one step")
        #expect(try set("exposure", 99) == .object(["exposure": .number(5)]), "clamped to the range")
        #expect(throws: CatalogError.unavailable(id: "photo.set-develop", why: "Develop has no Brightness slider.")) { try set("brightness", 10) }
        var none = LibraryCatalog(services: .fake())
        #expect(throws: CatalogError.self) {
            try Self.catalog.run("photo.set-develop", params: .object(["slider": .string("tint"), "value": .number(1)]), on: &none)
        }
    }

    /// Pick sets the flag: a picked photo stays picked, and nothing is recorded.
    @Test func flagSets() throws {
        var c = Dictionary(uniqueKeysWithValues: Self.states)["culled"] ?? LibraryCatalog()
        let steps = c.history.undo.count
        _ = try Self.catalog.run("metadata.pick", params: .object([:]), on: &c)
        #expect(c.items.filter { ["IMG_0001", "IMG_0002"].contains($0.id) }.map(\.flag) == [.pick, .pick])
        #expect(c.history.undo.count == steps)
        #expect(try Self.catalog.run("metadata.reject", params: .object([:]), on: &c).undoStep == "Reject")
        #expect(c.items.filter { ["IMG_0001", "IMG_0002"].contains($0.id) }.map(\.flag) == [.reject, .reject])
    }

    /// Rating, label, selection and paste do what the menu items do, with their params.
    @Test func runsWhatTheMenuRuns() throws {
        let states = Dictionary(uniqueKeysWithValues: Self.states)
        var c = states["two selected"] ?? LibraryCatalog()
        #expect(try Self.catalog.run("metadata.set-rating", params: .object(["stars": .number(4)]), on: &c).undoStep == "Set Rating")
        _ = try Self.catalog.run("metadata.set-label", params: .object(["label": .string("Blue")]), on: &c)
        let two = c.items.filter { ["IMG_0001", "IMG_0002"].contains($0.id) }
        #expect(two.map(\.rating) == [4, 4] && two.map(\.label) == [.blue, .blue])
        _ = try Self.catalog.run("metadata.set-label", params: .object([:]), on: &c)
        #expect(c.items.filter { ["IMG_0001", "IMG_0002"].contains($0.id) }.map(\.label) == [nil, nil])
        _ = try Self.catalog.run("edit.select", params: .object(["ids": .array([.string("IMG_0005"), .string("nope")])]), on: &c)
        #expect(c.selection == ["IMG_0005"])
        var loupe = states["loupe"] ?? LibraryCatalog()
        #expect(try Self.catalog.run("photo.paste-settings", params: .object([:]), on: &loupe).undoStep == "Paste Settings")
        #expect(loupe.items.first { $0.id == "IMG_0003" }?.develop.value(.exposure) == 1)
        let rated = c
        #expect(throws: CatalogError.self) { try Self.catalog.run("metadata.set-rating", params: .object(["stars": .number(6)]), on: &c) }
        #expect(c == rated)
    }

    /// Every spec keeps the catalog's laws on each state where it can run. As today, an edit that would change
    /// nothing (Pick on a pick, Crop opening a draft, Reset Crop inside one) records nothing; every edit records its
    /// step on at least one state.
    @Test func conformsOnLibraryStates() throws {
        var stepped = Set<String>()
        for (state, c) in Self.states {
            let doc = LibraryCatalogDoc(catalog: c)
            let problems = CatalogConformance.check(LibraryCatalogDoc.self, fixture: doc).filter { problem in
                let id = String(problem.prefix { $0 != ":" })
                let off = LibraryCatalogDoc.catalog.availability(id, on: doc).why != nil
                var ran = doc
                let example = LibraryCatalogDoc.catalog.spec(id)?.example ?? .object([:])
                let unchanged = (try? LibraryCatalogDoc.catalog.run(id, params: example, on: &ran)) != nil
                    && (try? ran.save()) == (try? doc.save())
                let noOpEdit = unchanged && ["stepNamedTitle", "editRecordsOneStep", "undoRestoresBytes", "redoRestoresBytes"]
                    .contains { problem.contains(": \($0):") }
                // Library has no recent files, so Open Recent's example names one it can't find.
                // Nor saved looks: Delete Look's example names one the fake store doesn't hold.
                let needsFile = ["file.open-recent", "look.delete"].contains(id) && problem.contains("exampleRuns")
                // The kernel's image.flip is titled Flip while its step names the axis (OC-8).
                let flipStep = problem == "image.flip: stepNamedTitle: its undo step reads \"Flip Horizontal\", not \"Flip\""
                return !((off || needsFile) && problem.contains("exampleRuns")) && !noOpEdit && !flipStep
            }
            #expect(problems.isEmpty, "\(state): \(problems.joined(separator: "\n"))")
            for spec in LibraryCatalog.commands where spec.kind == .edit && spec.availability(c).why == nil {
                var ran = c
                let step = try? Self.catalog.run(spec.id, params: spec.example, on: &ran).undoStep
                if step == spec.title || (spec.id == "image.flip" && step == "Flip Horizontal") { stepped.insert(spec.id) }
            }
        }
        // AJ-10: Library runs no filter, so no filter.<id> ever records a step.
        let edits = Set(LibraryCatalog.commands.filter { $0.kind == .edit && !$0.id.hasPrefix("filter.") }.map(\.id))
        #expect(edits.subtracting(stepped).isEmpty, "never recorded its step: \(edits.subtracting(stepped))")
    }

    @Test func idsKeepTheLedger() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("../command-ids/library.txt")
        let ledger = try String(contentsOf: url, encoding: .utf8)
        #expect(CommandIDLedger.check(Self.catalog.ids, ledger: ledger) == [])
        let listed = ledger.split(whereSeparator: \.isNewline).map(String.init).filter { !$0.isEmpty && !$0.hasPrefix("#") }
        #expect(listed.sorted() == Self.catalog.ids, "the ledger lists exactly the catalog's ids")
    }

    /// Today's menu table with two photos selected in the grid: each id's title and why it is off ("on" when it can run).
    @Test func menusUnchanged() {
        let two = Dictionary(uniqueKeysWithValues: Self.states)["two selected"] ?? LibraryCatalog()
        let table = LibraryCatalog.commands.map { "\($0.id) | \($0.title) | \($0.availability(two).why ?? "on")" }
        #expect(table == Self.golden, "\(table.joined(separator: "\n"))")
    }

    static let golden = [
        "file.import-folder | Import Folder… | on", "file.load-samples | Load Sample Photos | on", "file.export | Export… | on",
        "edit.undo | Undo | There is nothing to undo.", "edit.redo | Redo | There is nothing to redo.",
        "edit.select | Select | on", "edit.select-all | Select All | on", "edit.deselect | Deselect | on",
        "view.grid | Grid | The grid is already showing.", "view.loupe | Loupe | on",
        "view.zoom-in | Zoom In | on", "view.zoom-out | Zoom Out | on",
        "view.zoom-to-fit | Zoom to Fit | Open a photo in the loupe to zoom.",
        "view.actual-size | Actual Size | Open a photo in the loupe to zoom.", "view.sort | Sort By | on",
        "view.show-original | Show Original | Open a photo in the loupe to see its original.",
        "view.thumbnail-size | Thumbnail Size | on",
        "photo.copy-settings | Copy Settings | Develop isn't connected yet.", "photo.paste-settings | Paste Settings | Develop isn't connected yet.",
        "photo.reset-develop | Reset Develop | on", "photo.crop | Crop | Crop isn't connected yet.",
        "photo.reset-crop | Reset Crop | Crop isn't connected yet.",
        "metadata.set-rating | Set Rating | on", "metadata.pick | Pick | on", "metadata.reject | Reject | on",
        "metadata.clear-flag | Clear Flag | on", "metadata.set-label | Set Label | on", "metadata.auto-advance | Auto Advance | on",
        "file.recent | Recent Files | on", "file.open-recent | Open Recent | on", "file.clear-recent | Clear Menu | No Recent Files",
        "file.open-in | Open In | Open a photo in the loupe first.", "file.drop | Drop Files | on",
        "folders.list | List Folders | Import a folder to see its folders.",
        "view.show-folder | Show Folder | Import a folder to see its folders.",
        "export.set-folder | Choose Export Folder | Choose File > Export… to open the export sheet.",
        "export.apply-preset | Apply Preset | Choose File > Export… to open the export sheet.",
        "export.save-preset | Save as Preset | Choose File > Export… to open the export sheet.",
        "export.cancel | Cancel Export | No export is running.", "export.retry | Try Again | No photos failed to export.",
        "export.show-in-finder | Show in Finder | Nothing has been exported yet.",
        "export.close | Close Export | The export sheet isn't open.",
        "file.show-catalog | Show Catalog in Finder | The catalog file isn't damaged.",
        "notice.close | Close Notice | There is no notice to close.",
        "notice.show-failures | Show Failures | No files failed to import.",
    ] + ToneSlider.develop.map { "\(LibraryCatalog.resetSliderID($0)) | Reset \($0.title) | on" } + ["file.share-prepare | Share | on", "edit.copy | Copy | on",
        "thumbnails.stats | Thumbnail Stats | Thumbnails aren't kept on disk yet."]
        + ["catalog.backups | Catalog Backups | on", "catalog.restore-backup | Restore Catalog Backup | \(LibraryBackups.noBackups)"]
        + ["image.rotate-cw | Rotate Right | on", "image.rotate-ccw | Rotate Left | on", "image.rotate-180 | Rotate 180° | on",
           "image.flip | Flip | on"]
        + ["crop.set-aspect | Crop Ratio", "crop.swap | Swap Crop", "crop.set-frame | Crop Frame", "crop.apply | Crop",
           "crop.reset | Reset Crop"].map { "\($0) | Open a photo in the loupe to crop it." }
        + ["adjust.black-and-white | Black & White | on", "adjust.invert | Invert | on"]
        + ["Gaussian Blur", "Motion Blur", "Sharpen", "Reduce Noise", "Add Noise"].map { title in
            "filter.\(title.lowercased().replacingOccurrences(of: " ", with: "-")) | \(title) | Filters are in Photo."
        }
        + ["look.list | Looks | on", "look.apply | Apply Look | on", "look.save | Save Look | on", "look.delete | Delete Look | on"]
}
