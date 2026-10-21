// LibraryCommandCatalogTests.swift (adopt-command-catalog AC-l2): Library's catalog keeps the catalog's laws on
// Library's states, keeps its ledger, each command's availability is the reason today's menu shows, and the menu
// table is unchanged. Fails when a reason changes, an edit records no step, or an id goes missing. Linux-safe.
import Foundation
@testable import LibraryModel
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
        case "view.show-original": .some(c.services.unavailable["develop"] ?? c.developHelp
            ?? (c.canShowOriginal ? nil : "Open a photo in the loupe to see its original."))
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
                return !(off && problem.contains("exampleRuns")) && !noOpEdit
            }
            #expect(problems.isEmpty, "\(state): \(problems.joined(separator: "\n"))")
            for spec in LibraryCatalog.commands where spec.kind == .edit && spec.availability(c).why == nil {
                var ran = c
                if (try? Self.catalog.run(spec.id, params: spec.example, on: &ran).undoStep) == spec.title { stepped.insert(spec.id) }
            }
        }
        let edits = Set(LibraryCatalog.commands.filter { $0.kind == .edit }.map(\.id))
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
        "photo.copy-settings | Copy Settings | Develop isn't connected yet.", "photo.paste-settings | Paste Settings | Develop isn't connected yet.",
        "photo.reset-develop | Reset Develop | on", "photo.crop | Crop | Crop isn't connected yet.",
        "photo.reset-crop | Reset Crop | Crop isn't connected yet.",
        "metadata.set-rating | Set Rating | on", "metadata.pick | Pick | on", "metadata.reject | Reject | on",
        "metadata.clear-flag | Clear Flag | on", "metadata.set-label | Set Label | on", "metadata.auto-advance | Auto Advance | on",
    ]
}
