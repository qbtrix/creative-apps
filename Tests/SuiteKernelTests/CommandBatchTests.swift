// CommandBatchTests.swift (command-catalog CC-6, CJ2): `CommandCatalog.runBatch` on the fake canvas: an atomic batch
// puts the document back when a step refuses, a non-atomic one stops there and keeps what ran, and the report names
// each step tried. Written first, disabled by name; CC-7 builds the batch body and enables them.
import Foundation
import Testing
import SuiteKernel

@Suite struct CommandBatchTests {
    let catalog = FakeCanvasDocument.catalog
    static let add = CommandEnvelope(id: "rect.add", params: .object(["x": .number(1), "y": .number(2), "w": .number(3), "h": .number(4)]))
    static let missing = CommandEnvelope(id: "rect.select", params: .object(["id": .number(9)]))
    static let move = CommandEnvelope(id: "rect.move", params: .object(["dx": .number(5), "dy": .number(0)]))
    /// Add, then a select of a rect that isn't there (refused), then a move.
    static let refusedSecond = [add, missing, move]

    @Test func atomicBatchRollsBackOnARefusal() throws {
        var doc = FakeCanvasDocument.fixture
        let before = try FakeState(doc)
        let report = catalog.runBatch(Self.refusedSecond, on: &doc, atomic: true)
        #expect(try FakeState(doc) == before && doc.history.canUndo == false)
        #expect(report.stoppedAt == 1 && report.rolledBack && report.steps.map(\.id) == ["rect.add", "rect.select"])
        #expect(report.steps.map(\.ok) == [true, false] && report.steps.first?.undoStep == "Add Rectangle")
        #expect(report.steps.last?.error?.contains("There is no rect 9.") == true)
    }

    @Test func atomicBatchRollsBackAnUnavailableStep() throws {
        var doc = FakeCanvasDocument.fixture
        let before = try FakeState(doc)
        let report = catalog.runBatch([CommandEnvelope(id: "rect.select", params: .object(["id": .number(2)])), Self.move, Self.add],
                                      on: &doc, atomic: true)
        #expect(try FakeState(doc) == before && doc.selection == 1)
        #expect(report.stoppedAt == 1 && report.rolledBack && report.steps.last?.error?.contains("Unlock Rect 2 first.") == true)
    }

    @Test func nonAtomicBatchStopsAndKeepsWhatRan() throws {
        var doc = FakeCanvasDocument.fixture
        let report = catalog.runBatch(Self.refusedSecond, on: &doc, atomic: false)
        #expect(doc.rects.count == 3 && doc.history.steps == ["Add Rectangle"] && doc.rects.last?.x == 1)
        #expect(report.stoppedAt == 1 && !report.rolledBack && report.steps.count == 2, "the move after the refusal ran")
    }

    @Test func unknownStepStopsTheBatch() throws {
        var doc = FakeCanvasDocument.fixture
        let report = catalog.runBatch([Self.add, CommandEnvelope(id: "rect.nope", params: .object([:])), Self.move], on: &doc, atomic: false)
        #expect(report.stoppedAt == 1 && report.steps.last?.ok == false && report.steps.last?.error?.contains("rect.nope") == true)
        #expect(doc.rects.count == 3 && doc.rects.last?.x == 1)
    }

    @Test func reportNamesEveryStepWhenAllRun() throws {
        var doc = FakeCanvasDocument.fixture
        let steps = [Self.add, Self.move, CommandEnvelope(id: "rect.select", params: .object(["id": .number(1)])),
                     CommandEnvelope(id: "rect.list", params: .object([:]))]
        let report = catalog.runBatch(steps, on: &doc, atomic: true)
        #expect(report == BatchReport(steps: [.init(id: "rect.add", ok: true, undoStep: "Add Rectangle", error: nil),
                                              .init(id: "rect.move", ok: true, undoStep: "Move Rectangle", error: nil),
                                              .init(id: "rect.select", ok: true, undoStep: nil, error: nil),
                                              .init(id: "rect.list", ok: true, undoStep: nil, error: nil)],
                                      stoppedAt: nil, rolledBack: false))
        #expect(doc.history.steps == ["Add Rectangle", "Move Rectangle"] && doc.rects.last?.x == 6 && doc.selection == 1)
        #expect(try JSONValue(encoding: report).decode(BatchReport.self) == report)
    }

    @Test func emptyBatchDoesNothing() throws {
        var doc = FakeCanvasDocument.fixture
        let before = try FakeState(doc)
        #expect(catalog.runBatch([], on: &doc, atomic: true) == BatchReport(steps: [], stoppedAt: nil, rolledBack: false))
        #expect(try FakeState(doc) == before)
    }
}
