// FakeHistoryTests.swift (autosave-history AH-9): the fake app lists `history.read` and `history.jump`, so RJ-X31
// (Tests/RealJobs/fake/history-jump/) runs on the CLI. A jump lands on its index and records no step, the base row
// is "Open", and an index outside the steps throws and leaves the document as it was.
import Foundation
import Testing
import SuiteKernel

@Suite struct FakeHistoryTests {
    let catalog = FakeCanvasDocument.catalog
    /// One free rect, selected, as RJ-X31's `one.fake` reads after `rect.select`.
    static let one = FakeCanvasDocument(rects: [FakeRect(id: 1, name: "Rect 1", x: 10, y: 10, w: 100, h: 60)], selection: 1)

    /// `one` after `count` moves of (1, 2), each its own step.
    func moved(_ count: Int) throws -> FakeCanvasDocument {
        var doc = Self.one
        for _ in 0..<count { _ = try catalog.run("rect.move", params: .object(["dx": .number(1), "dy": .number(2)]), on: &doc) }
        return doc
    }

    @Test func theFakeListsTheHistoryCommands() {
        let history = HistoryCommands.specs(FakeCanvasDocument.self).map(\.id)
        #expect(history == ["history.read", "history.jump", "history.begin", "history.end", "history.undo-request"] && history.allSatisfy(catalog.ids.contains))
    }

    @Test func theBaseRowIsOpenAndReadListsEveryStep() throws {
        #expect(Self.one.historyListing == HistoryListing(base: "Open", steps: [], index: 0, savedIndex: 0))
        var doc = try moved(3)
        let read = try catalog.run("history.read", params: .object([:]), on: &doc)
        #expect(read.result == (try JSONValue(encoding: HistoryListing(base: "Open", steps: Array(repeating: "Move Rectangle", count: 3),
                                                                     index: 3, savedIndex: 0))))
    }

    @Test func aJumpLandsOnItsIndexAndRecordsNothing() throws {
        var doc = try moved(4)
        _ = try catalog.run("history.jump", params: .object(["index": .number(1)]), on: &doc)
        #expect(doc.historyListing.index == 1 && doc.historyListing.steps.count == 4)
        #expect(doc.rects.first?.x == 11 && doc.rects.first?.y == 12)
        #expect(doc.history.canRedo && doc.step(redo: true) && doc.rects.first?.x == 12)
        _ = try catalog.run("history.jump", params: .object(["index": .number(4)]), on: &doc)
        #expect(doc.rects == (try moved(4)).rects && doc.historyListing.steps.count == 4)
    }

    @Test func anEditAfterAJumpReplacesTheUndoneStepsAndNeverFoldsIntoTheLandedOne() throws {
        var doc = try moved(3)
        _ = try catalog.run("history.jump", params: .object(["index": .number(1)]), on: &doc)
        _ = try catalog.run("rect.move", params: .object(["dx": .number(5), "dy": .number(0)]), on: &doc)
        #expect(doc.historyListing.steps.count == 2 && doc.historyListing.index == 2 && !doc.history.canRedo)
        #expect(doc.rects.first?.x == 16 && doc.rects.first?.y == 12)
        let drag = JSONValue.object(["dx": .number(1), "dy": .number(0), "drag": .string("d")])
        _ = try catalog.run("rect.move", params: drag, on: &doc)
        _ = try catalog.run("history.jump", params: .object(["index": .number(3)]), on: &doc)
        _ = try catalog.run("rect.move", params: drag, on: &doc)
        #expect(doc.historyListing.steps.count == 4 && doc.historyListing.index == 4)
    }

    @Test func anIndexOutsideTheStepsThrowsAndChangesNothing() throws {
        var doc = try moved(2)
        let before = doc.rects
        #expect(throws: CatalogError.failed(id: "history.jump", message: "There is no step 3.")) {
            _ = try catalog.run("history.jump", params: .object(["index": .number(3)]), on: &doc)
        }
        #expect(throws: CatalogError.self) { try doc.jumpHistory(to: -1) }
        #expect(doc.rects == before && doc.historyListing.index == 2)
        #expect(catalog.availability("history.jump", on: Self.one).why == "There are no steps yet.")
    }
}
