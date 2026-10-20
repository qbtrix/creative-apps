// HistoryCommandsTests.swift (autosave-history AH-1 written, AH-6 turns on): `history.read` and `history.jump` on a
// test target with a kernel `History`. A read lists every step with the applied count, a jump lands on its index
// without recording a step, ends the open run, and an index outside the steps throws its sentence. The spec shape
// check runs now; the rest are disabled by name until AH-6 builds the bodies.
import Testing
import SuiteKernel

/// One number edited in named steps, its history holding the value each step replaced.
struct HistoryDoc: HistoryJumping {
    var value = 0, history = History<Int>()
    var historyListing: HistoryListing { history.listing(base: "Open") }
    /// Records a step named `name` that sets the value, folding steps under one `key`.
    mutating func set(_ value: Int, _ name: String, key: String? = nil) {
        history.record(name, self.value, key: key)
        self.value = value
    }
    /// The one-line conformance an app writes: the open run ended, then `History.jump(to:)`.
    mutating func jumpHistory(to index: Int) throws {
        history.endRun()
        var current = value
        history.jump(to: index) { old in defer { current = old }; return current }
        value = current
    }
    /// Undoes the last step; false when there is none.
    mutating func undo() -> Bool {
        var current = value
        let moved = history.undo { old in defer { current = old }; return current }
        value = current
        return moved
    }
}

@Suite struct HistoryCommandsTests {
    static let catalog = (try? CommandCatalog(app: "test", HistoryCommands.specs(HistoryDoc.self), history: { $0.history }))
    static let names = ["One", "Two", "Three", "Four", "Five"]
    /// Five steps setting 1...5, the last `undone` of them undone.
    static func doc(undone: Int = 0) -> HistoryDoc {
        var doc = HistoryDoc()
        for (n, name) in names.enumerated() { doc.set(n + 1, name) }
        for _ in 0..<undone { _ = doc.undo() }
        return doc
    }
    static func jump(_ index: Int) -> JSONValue { .object(["index": .number(Double(index))]) }

    @Test func specsAreReadAndJump() throws {
        let catalog = try #require(Self.catalog)
        #expect(catalog.ids == ["history.jump", "history.read"])
        #expect(catalog.spec("history.read")?.kind == .query)
        let jump = try #require(catalog.spec("history.jump"))
        #expect(jump.kind == .view && jump.title == "Jump in History")
        #expect(jump.params.validate(Self.jump(3)).isEmpty)
        #expect(!jump.params.validate(.object([:])).isEmpty)
    }
    @Test(.disabled("waits on AH-6")) func readListsStepsAndIndex() throws {
        let catalog = try #require(Self.catalog)
        var doc = Self.doc(undone: 2)
        let listing = try catalog.run("history.read", params: .object([:]), on: &doc).result.decode(HistoryListing.self)
        #expect(listing == HistoryListing(base: "Open", steps: Self.names, index: 3, savedIndex: 0))
    }
    @Test(.disabled("waits on AH-6")) func savedIndexFollowsSaveAndRollsOff() {
        var doc = Self.doc()
        doc.history.markSaved()
        #expect(doc.historyListing.savedIndex == 5)
        var short = HistoryDoc(history: History(limit: 2))
        for (n, name) in Self.names.enumerated() { short.set(n + 1, name) }
        #expect(short.historyListing.steps == ["Four", "Five"] && short.historyListing.savedIndex == nil)
    }
    @Test(.disabled("waits on AH-6")) func jumpRecordsNoStep() throws {
        let catalog = try #require(Self.catalog)
        var doc = Self.doc(undone: 2)
        let outcome = try catalog.run("history.jump", params: Self.jump(1), on: &doc)
        #expect(outcome.undoStep == nil)
        #expect(doc.history.steps == Self.names && doc.history.index == 1 && doc.value == 1)
        #expect(doc.undo() && doc.value == 0)
    }
    @Test(.disabled("waits on AH-6")) func jumpLandsOnIndex() throws {
        let catalog = try #require(Self.catalog)
        for index in 0...5 {
            var doc = Self.doc(undone: 2)
            _ = try catalog.run("history.jump", params: Self.jump(index), on: &doc)
            #expect(doc.history.index == index && doc.value == index, "\(index)")
        }
    }
    @Test(.disabled("waits on AH-6")) func outOfRangeThrowsSentence() throws {
        let catalog = try #require(Self.catalog)
        var doc = Self.doc()
        #expect(throws: CatalogError.failed(id: "history.jump", message: "There is no step 6.")) {
            try catalog.run("history.jump", params: Self.jump(6), on: &doc)
        }
        #expect(doc.history.index == 5 && doc.value == 5)
    }
    @Test(.disabled("waits on AH-6")) func noStepsUnavailable() throws {
        let catalog = try #require(Self.catalog)
        #expect(catalog.availability("history.jump", on: HistoryDoc()) == .unavailable("There are no steps yet."))
        #expect(catalog.availability("history.jump", on: Self.doc()) == .available)
        #expect(catalog.availability("history.read", on: HistoryDoc()) == .available)
    }
    @Test(.disabled("waits on AH-6")) func jumpEndsRun() throws {
        let catalog = try #require(Self.catalog)
        var doc = HistoryDoc()
        doc.set(1, "Move", key: "drag")
        doc.set(2, "Move", key: "drag")
        _ = try catalog.run("history.jump", params: Self.jump(1), on: &doc)
        doc.set(3, "Move", key: "drag")
        #expect(doc.history.steps == ["Move", "Move"] && doc.history.index == 2)
    }
}
