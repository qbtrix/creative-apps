// CommandWalkTests.swift (command-catalog CC-13, CJ4): the full walk on the fake canvas through its public catalog:
// list the ids, describe every one through JSON, run every example on the fixture, fold a drag into one undo step,
// undo back to the saved state and read clean, roll back an atomic batch, and save then open an equal document.
import Foundation
import Testing
import SuiteKernel

@Suite struct CommandWalkTests {
    let catalog = FakeCanvasDocument.catalog
    /// Every id in an order whose examples all run on one fixture: reads first, the file-flow commands, the fill
    /// commands on Rect 1 (the stop edits while it has three stops, `fill.gradient` last), then an add (which selects the
    /// free new rect), a move of it, undo and redo of that move, and last the remove. `file.drop` places a rect as a
    /// step, which a file command may not do here, so FakeCanvasFileFlowTests walks it instead; `history.jump` to 0
    /// would take the walk back to the fixture, so FakeHistoryTests walks it.
    static let fills = ["fill.read", "fill.type", "fill.stop-add", "fill.stop-move", "fill.stop-remove", "fill.stop-color",
                        "fill.angle", "fill.gradient"]
    static let walk = ["rect.list", "history.read", "rect.select", "doc.export-json", "file.recent", "file.open-recent", "file.open-in",
                       "file.clear-recent"] + fills + ["rect.add", "rect.move", "edit.undo", "edit.redo", "rect.remove"]

    /// `doc` saved and opened again: a document at its saved state, with a clean history.
    static func reopened(_ doc: FakeCanvasDocument) throws -> FakeCanvasDocument {
        try FakeCanvasDocument.open(doc.save(), name: "canvas.fake")
    }

    @Test func listNamesTheFakesTwentyThreeIdsSorted() {
        #expect(catalog.app == "fake")
        #expect(catalog.ids == ["doc.export-json", "edit.redo", "edit.undo", "file.clear-recent", "file.drop", "file.open-in",
                              "file.open-recent", "file.recent", "fill.angle", "fill.gradient", "fill.read", "fill.stop-add",
                              "fill.stop-color", "fill.stop-move", "fill.stop-remove", "fill.type", "history.jump", "history.read",
                              "rect.add", "rect.list", "rect.move", "rect.remove", "rect.select"])
        #expect(catalog.ids == catalog.ids.sorted() && Set(catalog.ids) == Set(Self.walk + ["file.drop", "history.jump"])
                && catalog.ids.count == Self.walk.count + 2)
        #expect(catalog.ids.allSatisfy(CommandCatalog<FakeCanvasDocument>.isValidID))
    }

    @Test func describeEveryIdRoundTripsThroughJSON() throws {
        for id in catalog.ids {
            let description = try #require(catalog.describe(id), "\(id) has no description")
            let spec = try #require(catalog.spec(id))
            #expect(description.app == "fake" && description.id == id && description.title == spec.title && description.kind == spec.kind)
            #expect(description.undoable == (spec.kind == .edit) && description.example == spec.example && description.params == spec.params.json)
            let text = try JSONEncoder().encode(description)
            #expect(try JSONDecoder().decode(CommandDescription.self, from: text) == description, "\(id) changed through JSON")
            #expect(try JSONValue(json: text).decode(CommandDescription.self) == description, "\(id) changed through JSONValue")
        }
        let all = try JSONEncoder().encode(catalog.describeAll())
        #expect(try JSONDecoder().decode([CommandDescription].self, from: all).map(\.id) == catalog.ids)
    }

    @Test func everyExampleValidatesAndRunsOnTheFixture() throws {
        var doc = FakeCanvasDocument.fixture
        for id in Self.walk {
            let spec = try #require(catalog.spec(id))
            #expect(spec.params.validate(spec.example).isEmpty, "\(id)'s example fails its schema")
            let before = try doc.save()
            let outcome: CommandOutcome
            do { outcome = try catalog.run(id, params: spec.example, on: &doc) } catch {
                Issue.record("\(id)'s example refused in the walk: \(error)"); continue
            }
            switch spec.kind {
            case .edit: #expect(outcome.undoStep == spec.title && doc.history.undoName == spec.title, "\(id) named \(outcome.undoStep ?? "no step")")
            case .query, .file: #expect(try outcome.undoStep == nil && doc.save() == before, "\(id) changed the bytes")
            case .view where !CatalogConformance.historyIDs.contains(id): #expect(try outcome.undoStep == nil && doc.save() == before)
            case .view: #expect(outcome.undoStep == nil)
            }
        }
        // The fills, then add, move, undo and redo of the move, and remove of the added rect: the fixture's rects,
        // Rect 1 with the new gradient.
        let fixture = FakeCanvasDocument.fixture.rects
        #expect(doc.rects.map(\.id) == fixture.map(\.id) && doc.rects.dropFirst() == fixture.dropFirst() && doc.selection == nil)
        #expect(doc.rects.first?.fill != fixture.first?.fill && doc.rects.first?.fill?.stops.count == 2)
        #expect(doc.history.steps == Self.fills.dropFirst().compactMap { catalog.spec($0)?.title }
                + ["Add Rectangle", "Move Rectangle", "Remove Rectangle"])
        // Each example also runs alone on a fresh fixture, except undo, redo and the jump, which refuse with no steps.
        for id in catalog.ids {
            var fresh = FakeCanvasDocument.fixture
            let example = try #require(catalog.spec(id)?.example)
            do { _ = try catalog.run(id, params: example, on: &fresh) } catch {
                #expect(CatalogConformance.historyIDs.contains(id) || id == "history.jump", "\(id)'s example refused on the fixture: \(error)")
                guard case .unavailable = error else { Issue.record("\(id) refused with \(error)"); continue }
            }
        }
    }

    @Test func aCoalescedDragIsOneUndoStep() throws {
        var doc = FakeCanvasDocument.fixture
        let before = try doc.save()
        for dx in [2.0, 3, 5] {
            let moved = try catalog.run(CommandEnvelope(id: "rect.move", params: .object(["dx": .number(dx), "dy": .number(1), "drag": .string("walk")])), on: &doc)
            #expect(moved.undoStep == "Move Rectangle")
        }
        #expect(doc.history.steps == ["Move Rectangle"] && doc.rects.first?.x == 20 && doc.rects.first?.y == 13)
        _ = try catalog.run("edit.undo", params: .object([:]), on: &doc)
        #expect(try doc.save() == before && !doc.history.canUndo, "one undo did not take back the whole drag")
        _ = try catalog.run("edit.redo", params: .object([:]), on: &doc)
        #expect(doc.rects.first?.x == 20 && doc.history.steps == ["Move Rectangle"])
        // A new drag token is a new step.
        _ = try catalog.run("rect.move", params: .object(["dx": .number(1), "dy": .number(0), "drag": .string("again")]), on: &doc)
        #expect(doc.history.steps == ["Move Rectangle", "Move Rectangle"])
    }

    @Test func undoBackToTheSavedStateReadsClean() throws {
        var doc = try Self.reopened(.fixture)
        _ = try catalog.run("rect.select", params: .object(["id": .number(1)]), on: &doc)
        let saved = try doc.save()
        #expect(!doc.history.isDirty)
        let example = try #require(catalog.spec("rect.add")?.example)
        _ = try catalog.run("rect.add", params: example, on: &doc)
        _ = try catalog.run("rect.move", params: .object(["dx": .number(4), "dy": .number(4), "drag": .string("d")]), on: &doc)
        _ = try catalog.run("rect.move", params: .object(["dx": .number(4), "dy": .number(4), "drag": .string("d")]), on: &doc)
        _ = try catalog.run("rect.remove", params: .object([:]), on: &doc)
        #expect(doc.history.isDirty && doc.history.steps == ["Add Rectangle", "Move Rectangle", "Remove Rectangle"])
        var undos = 0
        while catalog.availability("edit.undo", on: doc) == .available, undos < 10 {
            _ = try catalog.run("edit.undo", params: .object([:]), on: &doc); undos += 1
            #expect(doc.history.isDirty == (undos < 3), "after \(undos) undos isDirty reads \(doc.history.isDirty)")
        }
        #expect(try undos == 3 && !doc.history.isDirty && doc.save() == saved)
        #expect(doc.history.redoName == "Add Rectangle")
        _ = try catalog.run("edit.redo", params: .object([:]), on: &doc)
        #expect(doc.history.isDirty, "a redo past the saved state reads clean")
    }

    @Test func anAtomicBatchRollsBack() throws {
        var doc = FakeCanvasDocument.fixture
        let before = try doc.save()
        let example = try #require(catalog.spec("rect.add")?.example)
        let steps = [CommandEnvelope(id: "rect.add", params: example),
                     CommandEnvelope(id: "rect.move", params: .object(["dx": .number(5), "dy": .number(0)])),
                     CommandEnvelope(id: "rect.select", params: .object(["id": .number(2)])),
                     CommandEnvelope(id: "rect.remove", params: .object([:])),
                     CommandEnvelope(id: "rect.list", params: .object([:]))]
        let report = catalog.runBatch(steps, on: &doc, atomic: true)
        #expect(report.stoppedAt == 3 && report.rolledBack && report.steps.map(\.ok) == [true, true, true, false])
        #expect(report.steps.compactMap(\.undoStep) == ["Add Rectangle", "Move Rectangle"])
        #expect(report.steps.last?.error?.contains("Unlock Rect 2 first.") == true)
        #expect(try doc.save() == before && doc.selection == 1 && doc.history.steps.isEmpty && !doc.history.isDirty)
        #expect(try JSONValue(encoding: report).decode(BatchReport.self) == report)
        // The same batch, not atomic, keeps the three steps that ran.
        var kept = FakeCanvasDocument.fixture
        #expect(catalog.runBatch(steps, on: &kept, atomic: false).rolledBack == false)
        #expect(kept.rects.count == 3 && kept.selection == 2 && kept.history.steps == ["Add Rectangle", "Move Rectangle"])
    }

    @Test func saveThenOpenGivesAnEqualDocument() throws {
        var doc = FakeCanvasDocument.fixture
        let example = try #require(catalog.spec("rect.add")?.example)
        _ = try catalog.run("rect.add", params: example, on: &doc)
        _ = try catalog.run("rect.add", params: .object(["x": .number(-3.5), "y": .number(0.25), "w": .number(7), "h": .number(9), "name": .string("Card \u{1F0A1}")]), on: &doc)
        _ = try catalog.run("rect.move", params: .object(["dx": .number(0.1), "dy": .number(-0.2)]), on: &doc)
        for walked in [FakeCanvasDocument.fixture, doc, FakeCanvasDocument()] {
            let bytes = try walked.save()
            var opened = try FakeCanvasDocument.open(bytes, name: "canvas.fake")
            #expect(try opened.rects == walked.rects && opened.save() == bytes && !opened.history.isDirty)
            let listed = try catalog.run("rect.list", params: .object([:]), on: &opened)
            #expect(try listed.result.decode([FakeRect].self) == walked.rects)
        }
        let exported = try catalog.run("doc.export-json", params: .object([:]), on: &doc)
        guard case .object(let fields) = exported.result, case .string(let json)? = fields["json"] else {
            Issue.record("doc.export-json gave \(exported.result)"); return
        }
        #expect(try FakeCanvasDocument.open(Data(json.utf8), name: "canvas.json").rects == doc.rects)
    }
}
