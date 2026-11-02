// AdjustCommandsTests.swift (adjust-everywhere AJ-1 written, AJ-6 turns the
// runs on): the adjust.*, filter.* and look.* commands on a test target with a
// History. The ids, kinds and reasons hold on the stubs; once AJ-6 lands each
// edit is one undo step, look.apply then undo restores every value, and a look
// saved from one target gives a second the same values. Mutations (AJ-6):
// SuiteImaging.AdjustCommands (`.lookIsOneStep`, `.lookKeepsTone`).
import Testing
import SuiteImaging
import SuiteKernel
import SuiteModel

/// One picture's tone, adjust and kinds, the filters run on it, its looks store and its undo history.
struct AdjustTestTarget: AdjustTarget {
    var look = LookPreset(id: "", name: "")
    var filters: [ImagingFilter] = []
    var help: String?
    var noLayer: String?
    var history = History<LookPreset>()
    let store: FakePresetStore
    var adjustHelp: String? { help }
    var filterHelp: String? { noLayer }
    var currentLook: LookPreset { look }
    var kinds: [ImagingKind] { look.kinds }
    var looks: any PresetStoring { store }

    init(help: String? = nil, noLayer: String? = nil, store: FakePresetStore = FakePresetStore()) {
        (self.help, self.noLayer, self.store) = (help, noLayer, store)
    }

    mutating func setKinds(_ k: [ImagingKind], name: String) throws {
        history.record(name, look, key: nil)
        look.kinds = k
    }

    mutating func applyFilter(_ f: ImagingFilter, name: String) throws {
        history.record(name, look, key: nil)
        filters.append(f)
    }

    mutating func applyLook(_ l: LookPreset, name: String) throws {
        history.record(name, look, key: nil)
        (look.tone, look.adjust, look.kinds) = (l.tone, l.adjust, l.kinds)
    }

    mutating func undo() -> Bool {
        var current = look
        defer { look = current }
        return history.undo { old in defer { current = old }; return current }
    }
}

func adjustCatalog() throws -> CommandCatalog<AdjustTestTarget> {
    try CommandCatalog(app: "test", AdjustCommands.specs(AdjustTestTarget.self)) { $0.history }
}

@Suite struct AdjustCommandsTests {
    static let filterIDs = ImagingFilter.ids.map { "filter.\($0)" }

    /// The eleven ids and kinds; `adjustHelp` blocks every edit, `filterHelp` only the filters.
    @Test func contractShape() throws {
        let catalog = try adjustCatalog()
        #expect(Set(catalog.ids) == Set(["adjust.black-and-white", "adjust.invert", "look.list", "look.apply", "look.save", "look.delete"] + Self.filterIDs))
        let kinds = Dictionary(uniqueKeysWithValues: catalog.describeAll().map { ($0.id, $0.kind) })
        #expect(kinds["look.list"] == .query && kinds["look.save"] == .file && kinds["look.delete"] == .file)
        #expect(catalog.ids.filter { kinds[$0] == .edit }.count == 8)
        let closed = AdjustTestTarget(help: "Open a photo first.")
        for id in catalog.ids where kinds[id] == .edit { #expect(catalog.availability(id, on: closed).why == "Open a photo first.", "\(id)") }
        let noLayer = AdjustTestTarget(noLayer: "Select a pixel layer.")
        for id in Self.filterIDs { #expect(catalog.availability(id, on: noLayer).why == "Select a pixel layer.", "\(id)") }
        #expect(catalog.availability("adjust.invert", on: noLayer) == .available)
        for id in ImagingFilter.ids { #expect(ImagingFilter.defaults(id)?.id == id) }
    }

    /// Each edit records one step named its title.
    @Test func eachEditIsOneNamedStep() throws {
        let catalog = try adjustCatalog()
        var doc = AdjustTestTarget()
        #expect(try catalog.run("adjust.invert", params: .object([:]), on: &doc).undoStep == "Invert")
        #expect(doc.kinds == [.invert])
        #expect(try catalog.run("adjust.black-and-white", params: .object([:]), on: &doc).undoStep == "Black & White")
        let blur = try catalog.run("filter.gaussian-blur", params: .object(["radius": .number(4)]), on: &doc)
        #expect(blur.undoStep == "Gaussian Blur" && doc.filters == [.gaussianBlur(radius: 4)])
        #expect(doc.history.steps.count == 3)
    }

    /// look.apply is one step and undo restores tone, adjust and kinds.
    @Test func lookIsOneStep() throws {
        let catalog = try adjustCatalog()
        var doc = AdjustTestTarget()
        let before = doc.look
        #expect(try catalog.run("look.apply", params: .object(["id": .string("bw-high-contrast")]), on: &doc).undoStep == "Apply Look")
        #expect(doc.history.steps.count == 1 && doc.look.kinds == BuiltInLooks.look("bw-high-contrast")?.kinds)
        #expect(doc.undo() && doc.look == before)
        #expect(throws: CatalogError.self) { try catalog.run("look.apply", params: .object(["id": .string("nope")]), on: &doc) }
    }

    /// A look saved from one target applies the same tone, adjust and kinds to another; built-ins can't be deleted.
    @Test func lookKeepsTone() throws {
        let catalog = try adjustCatalog()
        let store = FakePresetStore()
        var first = AdjustTestTarget(store: store), second = AdjustTestTarget(store: store)
        first.look.tone = ToneSettings.neutral.setting(.contrast, to: 30)
        first.look.adjust = AdjustSettings(exposure: 0.5)
        first.look.kinds = [.invert]
        let saved = try catalog.run("look.save", params: .object(["name": .string("Mine")]), on: &first)
        guard case .object(let fields) = saved.result, case .string(let id)? = fields["id"] else { Issue.record("no id"); return }
        #expect(saved.undoStep == nil && store.list(kind: LookPreset.recordKind).count == 1)
        _ = try catalog.run("look.apply", params: .object(["id": .string(id)]), on: &second)
        #expect(second.look.tone == first.look.tone && second.look.adjust == first.look.adjust && second.look.kinds == [.invert])
        #expect(throws: CatalogError.self) { try catalog.run("look.save", params: .object(["name": .string("MINE")]), on: &first) }
        #expect(throws: CatalogError.self) { try catalog.run("look.delete", params: .object(["id": .string("bw")]), on: &first) }
        let list = try catalog.run("look.list", params: .object([:]), on: &first)
        guard case .array(let rows) = list.result else { Issue.record("not a list"); return }
        #expect(rows.count == 7)
    }

    /// Weights replace the B&W kind in place and no weights remove it; Invert toggles off again.
    @Test func kindsReplaceAndToggle() throws {
        let catalog = try adjustCatalog()
        var doc = AdjustTestTarget()
        doc.look.kinds = [.blackAndWhite(.neutral), .invert]
        let red = GrayWeights(red: 100, yellow: 60, green: 40, cyan: 60, blue: 20, magenta: 80)
        let weights: [String: JSONValue] = ["red": .number(100), "yellow": .number(60), "green": .number(40),
                                            "cyan": .number(60), "blue": .number(20), "magenta": .number(80)]
        _ = try catalog.run("adjust.black-and-white", params: .object(["weights": .object(weights)]), on: &doc)
        #expect(doc.kinds == [.blackAndWhite(red), .invert])
        _ = try catalog.run("adjust.invert", params: .object([:]), on: &doc)
        #expect(doc.kinds == [.blackAndWhite(red)])
        _ = try catalog.run("adjust.black-and-white", params: .object([:]), on: &doc)
        #expect(doc.kinds.isEmpty && doc.history.steps.count == 3)
    }

    /// A built-in's name is taken ignoring case; a saved look deletes once, its id its name's slug; an unknown id is refused.
    @Test func savedLookDeletes() throws {
        let catalog = try adjustCatalog()
        let store = FakePresetStore()
        var doc = AdjustTestTarget(store: store)
        #expect(throws: CatalogError.unavailable(id: "look.save", why: "You already have a look named \u{201C}black & white\u{201D}.")) {
            try catalog.run("look.save", params: .object(["name": .string("black & white")]), on: &doc)
        }
        let saved = try catalog.run("look.save", params: .object(["name": .string("My Look")]), on: &doc)
        #expect(saved.result == .object(["id": .string("my-look")]))
        _ = try catalog.run("look.delete", params: .object(["id": .string("my-look")]), on: &doc)
        #expect(store.list(kind: LookPreset.recordKind).isEmpty)
        #expect(throws: CatalogError.self) { try catalog.run("look.delete", params: .object(["id": .string("my-look")]), on: &doc) }
        #expect(throws: CatalogError.unavailable(id: "look.delete", why: "A built-in look can't be deleted.")) {
            try catalog.run("look.delete", params: .object(["id": .string("bw")]), on: &doc)
        }
    }
}
