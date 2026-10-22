// CommandCatalogTests.swift (command-catalog CC-6, CJ2): `CommandCatalog.run` on the fake canvas: ids are checked,
// unknown, malformed, unavailable and failed runs each name their cause and change nothing, an edit records exactly
// one undo step, and describe round trips. Written first, disabled by name; CC-7 builds the bodies and enables them.
import Foundation
import Testing
import SuiteKernel

/// What a run may change on the fake: its rects, its selection, its history's steps and its saved bytes.
struct FakeState: Equatable {
    var rects: [FakeRect], selection: Int?, steps: [String], bytes: Data
    init(_ doc: FakeCanvasDocument) throws {
        (rects, selection, steps, bytes) = (doc.rects, doc.selection, doc.history.steps, try doc.save())
    }
}

/// The refusal `id` with `params` throws on `doc`, nil when it ran.
func refusal(_ id: String, _ params: JSONValue, on doc: inout FakeCanvasDocument,
             catalog: CommandCatalog<FakeCanvasDocument> = FakeCanvasDocument.catalog) -> CatalogError? {
    do { _ = try catalog.run(id, params: params, on: &doc); return nil } catch { return error }
}

@Suite struct CommandCatalogTests {
    let catalog = FakeCanvasDocument.catalog
    static let addParams: JSONValue = .object(["x": .number(10), "y": .number(20), "w": .number(30), "h": .number(40)])

    /// A query spec under `id` that does nothing.
    static func spec(_ id: String) -> CommandSpec<FakeCanvasDocument> {
        .typed(id, title: "Noop", summary: "Does nothing.", kind: .query, params: FakeCanvasDocument.NoParams.self,
               schema: ParamSchema.none, example: .object([:])) { _, _ in JSONValue.object([:]) }
    }
    static func catalog(_ ids: [String]) throws -> CommandCatalog<FakeCanvasDocument> {
        try CommandCatalog(app: "fake", ids.map(spec), history: { $0.history })
    }

    @Test func badOrDuplicateIdsAreRefused() throws {
        for bad in ["", "Rect.Add", "rect add", "rect_add", String(repeating: "a", count: 65)] {
            #expect(throws: (any Error).self, "\(bad) was accepted") { try Self.catalog([bad]) }
        }
        #expect(throws: (any Error).self) { try Self.catalog(["rect.add", "rect.add"]) }
        #expect(try Self.catalog(["doc.export-json", "rect.add", String(repeating: "a", count: 64)]).ids.count == 3)
    }

    @Test func unknownIdChangesNothing() throws {
        var doc = FakeCanvasDocument.fixture
        let before = try FakeState(doc)
        #expect(refusal("rect.nope", .object([:]), on: &doc) == .unknownCommand("rect.nope"))
        #expect(throws: CatalogError.unknownCommand("Rect.Add")) { try catalog.run(CommandEnvelope(id: "Rect.Add", params: .object([:])), on: &doc) }
        #expect(try FakeState(doc) == before)
    }

    @Test func malformedParamsNameThePathAndRunNothing() throws {
        var doc = FakeCanvasDocument.fixture
        let before = try FakeState(doc)
        var wrong = ["x": JSONValue.string("1"), "y": .number(20), "w": .number(30), "h": .number(40)]
        guard case .malformedParams(let id, let issues)? = refusal("rect.add", .object(wrong), on: &doc) else {
            Issue.record("a string for x was not refused as malformed"); return
        }
        #expect(id == "rect.add" && issues == [SchemaIssue(path: "/x", message: "expected number")])
        wrong["x"] = nil
        #expect(refusal("rect.add", .object(wrong), on: &doc).map { if case .malformedParams = $0 { true } else { false } } == true)
        var extra = ["dx": JSONValue.number(1), "dy": .number(1), "zz": .bool(true)]
        #expect(refusal("rect.move", .object(extra), on: &doc).map { if case .malformedParams = $0 { true } else { false } } == true)
        extra["zz"] = nil
        #expect(refusal("rect.move", .array([.object(extra)]), on: &doc).map { if case .malformedParams = $0 { true } else { false } } == true)
        #expect(try FakeState(doc) == before)
    }

    @Test func unavailableCarriesTheWhyAndChangesNothing() throws {
        var doc = FakeCanvasDocument.fixture
        try doc.select(2)
        let before = try FakeState(doc)
        #expect(refusal("rect.move", .object(["dx": .number(5), "dy": .number(0)]), on: &doc)
                == .unavailable(id: "rect.move", why: "Unlock Rect 2 first."))
        #expect(refusal("rect.remove", .object([:]), on: &doc) == .unavailable(id: "rect.remove", why: "Unlock Rect 2 first."))
        #expect(refusal("edit.undo", .object([:]), on: &doc) == .unavailable(id: "edit.undo", why: "There is nothing to undo."))
        // A run that would make itself available: checked on the target before it runs, it never runs.
        let gated = CommandSpec<FakeCanvasDocument>.typed(
            "rect.add-after-edit", title: "Add After Edit", summary: "Adds a rectangle once there is an edit.", kind: .edit,
            params: FakeCanvasDocument.AddRect.self, example: Self.addParams,
            availability: { $0.history.canUndo ? .available : .unavailable("Edit first.") }) { doc, p in doc.add(p) }
        let gatedCatalog = try CommandCatalog(app: "fake", [gated], history: { $0.history })
        #expect(refusal("rect.add-after-edit", Self.addParams, on: &doc, catalog: gatedCatalog) == .unavailable(id: "rect.add-after-edit", why: "Edit first."))
        #expect(try FakeState(doc) == before)
    }

    enum Boom: Error { case midway }

    @Test func failedRunRollsBack() throws {
        var doc = FakeCanvasDocument.fixture
        let before = try FakeState(doc)
        #expect(refusal("rect.select", .object(["id": .number(9)]), on: &doc) == .failed(id: "rect.select", message: "There is no rect 9."))
        let halfway = CommandSpec<FakeCanvasDocument>.typed(
            "rect.add-then-fail", title: "Add Then Fail", summary: "Adds a rectangle, then fails.", kind: .edit,
            params: FakeCanvasDocument.AddRect.self, example: Self.addParams) { (doc: inout FakeCanvasDocument, p: FakeCanvasDocument.AddRect) throws -> JSONValue in
            _ = doc.add(p); throw Boom.midway
        }
        let failing = try CommandCatalog(app: "fake", [halfway], history: { $0.history })
        #expect(refusal("rect.add-then-fail", Self.addParams, on: &doc, catalog: failing) == .failed(id: "rect.add-then-fail", message: "midway"))
        #expect(try FakeState(doc) == before)
    }

    @Test func editRecordsExactlyOneNamedStep() throws {
        var doc = FakeCanvasDocument.fixture
        let added = try catalog.run("rect.add", params: Self.addParams, on: &doc)
        #expect(added.undoStep == "Add Rectangle" && doc.history.steps == ["Add Rectangle"] && doc.history.undoName == "Add Rectangle")
        #expect(try added.result.decode(FakeRect.self) == FakeRect(id: 3, name: "Rect 3", x: 10, y: 20, w: 30, h: 40))
        let listed = try catalog.run("rect.list", params: .object([:]), on: &doc)
        #expect(try listed.undoStep == nil && listed.result.decode([FakeRect].self) == doc.rects && doc.rects.count == 3)
        let selected = try catalog.run("rect.select", params: .object(["id": .number(1)]), on: &doc)
        #expect(selected.undoStep == nil && doc.selection == 1 && doc.history.steps == ["Add Rectangle"])
        for dx in [1.0, 2, 3] {
            let moved = try catalog.run(CommandEnvelope(id: "rect.move", params: .object(["dx": .number(dx), "dy": .number(0), "drag": .string("d1")])), on: &doc)
            #expect(moved.undoStep == "Move Rectangle")
        }
        #expect(doc.history.steps == ["Add Rectangle", "Move Rectangle"] && doc.rects.first?.x == 16)
        _ = try catalog.run("edit.undo", params: .object([:]), on: &doc)
        #expect(doc.rects.first?.x == 10 && doc.history.undoName == "Add Rectangle")
    }

    @Test func envelopeRunsLikeIdAndParams() throws {
        let line = Data(#"{"id":"rect.add","params":{"x":10,"y":20,"w":30,"h":40}}"#.utf8)
        let step = try JSONDecoder().decode(CommandEnvelope.self, from: line)
        var a = FakeCanvasDocument.fixture, b = FakeCanvasDocument.fixture
        #expect(try catalog.run(step, on: &a) == catalog.run("rect.add", params: Self.addParams, on: &b))
        #expect(try FakeState(a) == FakeState(b))
    }

    @Test func describeRoundTripsThroughJSON() throws {
        #expect(catalog.describe("rect.nope") == nil && catalog.describeAll().map(\.id) == catalog.ids)
        let add = try #require(catalog.describe("rect.add"))
        #expect(add.app == "fake" && add.kind == .edit && add.undoable && add.params == FakeCanvasDocument.AddRect.paramSchema.json)
        #expect(catalog.describe("rect.list")?.undoable == false && catalog.describe("edit.undo")?.kind == .view)
        let all = try JSONEncoder().encode(catalog.describeAll())
        #expect(try JSONDecoder().decode([CommandDescription].self, from: all) == catalog.describeAll())
        #expect(all.count <= 20 * 1024, "describeAll is \(all.count) bytes") // 29 ids with the transform commands (TT-8)
    }

    /// 1,000 seeded mutations of each example (types swapped, keys dropped and added, huge strings) refuse or run.
    @Test func fuzzedParamsNeverCrash() throws {
        var seed: UInt64 = 0x5eed
        func next(_ n: Int) -> Int { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Int((seed >> 33) % UInt64(n)) }
        let swaps: [JSONValue] = [.null, .bool(true), .number(-1e300), .number(1.5), .string(String(repeating: "x", count: 10_000)),
                                  .array([.number(1)]), .object(["a": .null])]
        for id in catalog.ids {
            guard case .object(let example)? = catalog.spec(id)?.example else { Issue.record("\(id) has no object example"); continue }
            for _ in 0..<1000 {
                var params = example
                let keys = Array(params.keys).sorted() + ["x", "dx", "id", "zz"]
                switch next(3) {
                case 0: params[keys[next(keys.count)]] = swaps[next(swaps.count)]
                case 1: params[keys[next(keys.count)]] = nil
                default: params[keys[next(keys.count)]] = .number(Double(next(1000)))
                }
                var doc = FakeCanvasDocument.fixture
                let before = try FakeState(doc)
                let refused = refusal(id, .object(params), on: &doc)
                switch refused {
                case nil, .malformedParams?, .unavailable?, .failed?: break
                case let other?: Issue.record("\(id) \(params): \(other)")
                }
                if refused != nil { #expect(try FakeState(doc) == before, "\(id) \(params) changed the document") }
            }
        }
    }

    /// CJ2: add with the example names its step; a move on a locked Rect 1 refuses with the why; an atomic
    /// three-step batch whose second step is refused leaves the document as it was.
    @Test func cj2CatalogRunsRefusesAndRollsBack() throws {
        var doc = FakeCanvasDocument.fixture
        let example = try #require(catalog.spec("rect.add")?.example)
        _ = try catalog.run("rect.add", params: example, on: &doc)
        #expect(doc.rects.count == 3 && doc.history.undoName == "Add Rectangle")
        var locked = FakeCanvasDocument(rects: [FakeRect(id: 1, name: "Rect 1", x: 0, y: 0, w: 10, h: 10, locked: true)], selection: 1)
        let lockedBefore = try FakeState(locked)
        #expect(refusal("rect.move", .object(["dx": .number(5), "dy": .number(0)]), on: &locked) == .unavailable(id: "rect.move", why: "Unlock Rect 1 first."))
        #expect(try FakeState(locked) == lockedBefore)
        var batched = FakeCanvasDocument.fixture
        let before = try FakeState(batched)
        let report = catalog.runBatch([CommandEnvelope(id: "rect.add", params: example), CommandEnvelope(id: "rect.select", params: .object(["id": .number(9)])),
                                       CommandEnvelope(id: "rect.list", params: .object([:]))], on: &batched, atomic: true)
        #expect(try report.stoppedAt == 1 && report.rolledBack && FakeState(batched) == before)
    }
}
