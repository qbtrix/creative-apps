// HistoryCommandsTests.swift: the kernel history commands on a test target with a kernel `History`. A read lists
// every step with the applied count and who made it, a jump lands on its index without recording a step, ends the
// open run, and an index outside the steps throws its sentence. `history.begin` / `history.end` span a request and
// `history.undo-request` undoes its applied tail in one call; a run under an agent origin (the live chokepoint)
// marks every step it records as that agent's.
import Testing
import SuiteKernel

/// One number edited in named steps, its history holding the value each step replaced.
struct HistoryDoc: HistoryJumping {
    var value = 0, history = History<Int>()
    var historyListing: HistoryListing { history.listing(base: "Open") }
    mutating func setHistoryRequest(_ name: String?) -> Bool { history.setRequest(name) }
    /// Records a step named `name` that sets the value, folding steps under one `key`.
    mutating func set(_ value: Int, _ name: String, key: String? = nil) {
        history.record(name, self.value, key: key)
        self.value = value
    }
    /// The one-line conformance an app writes: `History.jumpEndingRun(to:)` over its undo adapter.
    mutating func jumpHistory(to index: Int) throws {
        var current = value
        history.jumpEndingRun(to: index) { old in defer { current = old }; return current }
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
        #expect(catalog.ids == ["history.begin", "history.end", "history.jump", "history.read", "history.undo-request"])
        #expect(catalog.spec("history.read")?.kind == .query)
        let jump = try #require(catalog.spec("history.jump"))
        #expect(jump.kind == .view && jump.title == "Jump in History")
        #expect(jump.params.validate(Self.jump(3)).isEmpty)
        #expect(!jump.params.validate(.object([:])).isEmpty)
    }
    @Test func readListsStepsAndIndex() throws {
        let catalog = try #require(Self.catalog)
        var doc = Self.doc(undone: 2)
        let listing = try catalog.run("history.read", params: .object([:]), on: &doc).result.decode(HistoryListing.self)
        #expect(listing == HistoryListing(base: "Open", steps: Self.names, index: 3, savedIndex: 0))
    }
    @Test func savedIndexFollowsSaveAndRollsOff() {
        var doc = Self.doc()
        doc.history.markSaved()
        #expect(doc.historyListing.savedIndex == 5)
        var short = HistoryDoc(history: History(limit: 2))
        for (n, name) in Self.names.enumerated() { short.set(n + 1, name) }
        #expect(short.historyListing.steps == ["Four", "Five"] && short.historyListing.savedIndex == nil)
    }
    @Test func jumpRecordsNoStep() throws {
        let catalog = try #require(Self.catalog)
        var doc = Self.doc(undone: 2)
        let outcome = try catalog.run("history.jump", params: Self.jump(1), on: &doc)
        #expect(outcome.undoStep == nil)
        #expect(doc.history.steps == Self.names && doc.history.index == 1 && doc.value == 1)
        #expect(doc.undo() && doc.value == 0)
    }
    @Test func jumpLandsOnIndex() throws {
        let catalog = try #require(Self.catalog)
        for index in 0...5 {
            var doc = Self.doc(undone: 2)
            _ = try catalog.run("history.jump", params: Self.jump(index), on: &doc)
            #expect(doc.history.index == index && doc.value == index, "\(index)")
        }
    }
    @Test func outOfRangeThrowsSentence() throws {
        let catalog = try #require(Self.catalog)
        var doc = Self.doc()
        #expect(throws: CatalogError.failed(id: "history.jump", message: "There is no step 6.")) {
            try catalog.run("history.jump", params: Self.jump(6), on: &doc)
        }
        #expect(doc.history.index == 5 && doc.value == 5)
    }
    @Test func noStepsUnavailable() throws {
        let catalog = try #require(Self.catalog)
        #expect(catalog.availability("history.jump", on: HistoryDoc()) == .unavailable("There are no steps yet."))
        #expect(catalog.availability("history.jump", on: Self.doc()) == .available)
        #expect(catalog.availability("history.read", on: HistoryDoc()) == .available)
    }
    @Test func jumpEndsRun() throws {
        let catalog = try #require(Self.catalog)
        var doc = HistoryDoc()
        doc.set(1, "Move", key: "drag")
        doc.set(2, "Move", key: "drag")
        _ = try catalog.run("history.jump", params: Self.jump(1), on: &doc)
        doc.set(3, "Move", key: "drag")
        #expect(doc.history.steps == ["Move", "Move"] && doc.history.index == 2)
    }

    static func named(_ name: String) -> JSONValue { .object(["name": .string(name)]) }
    /// `values` set under `origin`, each its own step.
    static func set(_ doc: inout HistoryDoc, _ values: [Int], as origin: StepOrigin) {
        StepOrigin.$current.withValue(origin) { for v in values { doc.set(v, "Set \(v)") } }
    }
    static let claude = StepOrigin.agent(client: "claude", request: nil)

    @Test func readListsOriginsAndTheOpenRequest() throws {
        let catalog = try #require(Self.catalog)
        var doc = HistoryDoc()
        doc.set(1, "Set 1")
        _ = try catalog.run("history.begin", params: Self.named("AI: Birds"), on: &doc)
        Self.set(&doc, [2], as: Self.claude)
        let listing = try catalog.run("history.read", params: .object([:]), on: &doc).result.decode(HistoryListing.self)
        #expect(listing.origins == [.user, .agent(client: "claude", request: "AI: Birds")])
        #expect(listing.openRequest == "AI: Birds")
    }
    @Test func beginTwiceAndEndWithNoneRefuse() throws {
        let catalog = try #require(Self.catalog)
        var doc = HistoryDoc()
        #expect(catalog.availability("history.end", on: doc) == .unavailable("No request is open."))
        _ = try catalog.run("history.begin", params: Self.named("AI: Birds"), on: &doc)
        #expect(throws: CatalogError.failed(id: "history.begin", message: "Request AI: Birds is open; end it first.")) {
            try catalog.run("history.begin", params: Self.named("AI: Sun"), on: &doc)
        }
        _ = try catalog.run("history.end", params: .object([:]), on: &doc)
        #expect(doc.historyListing.openRequest == nil)
    }
    @Test func undoRequestUndoesItsStepsInOneCall() throws {
        let catalog = try #require(Self.catalog)
        var doc = HistoryDoc()
        doc.set(1, "Set 1")
        #expect(catalog.availability("history.undo-request", on: doc) == .unavailable("No applied step belongs to a request."))
        _ = try catalog.run("history.begin", params: Self.named("AI: Birds"), on: &doc)
        Self.set(&doc, [2, 3, 4], as: Self.claude)
        _ = try catalog.run("history.end", params: .object([:]), on: &doc)
        #expect(throws: CatalogError.failed(id: "history.undo-request", message: "There is no request AI: Sun.")) {
            try catalog.run("history.undo-request", params: Self.named("AI: Sun"), on: &doc)
        }
        let done = try catalog.run("history.undo-request", params: Self.named("AI: Birds"), on: &doc)
        #expect(done.result == .object(["undone": .number(3)]))
        #expect(doc.value == 1 && doc.history.index == 1 && doc.history.steps.count == 4)
        #expect(catalog.availability("history.undo-request", on: doc) == .unavailable("No applied step belongs to a request."))
    }
    @Test func undoRequestRefusesWhenALaterStepFollows() throws {
        let catalog = try #require(Self.catalog)
        var doc = HistoryDoc()
        _ = try catalog.run("history.begin", params: Self.named("AI: Birds"), on: &doc)
        Self.set(&doc, [1, 2], as: Self.claude)
        doc.set(3, "Set 3")
        let refusal = CatalogError.failed(id: "history.undo-request", message: "Later steps follow request AI: Birds; undo them first.")
        #expect(throws: refusal) { try catalog.run("history.undo-request", params: Self.named("AI: Birds"), on: &doc) }
        Self.set(&doc, [4], as: Self.claude)
        #expect(throws: refusal) { try catalog.run("history.undo-request", params: Self.named("AI: Birds"), on: &doc) }
        #expect(doc.value == 4 && doc.history.index == 4)
    }
    /// The live chokepoint: `LiveCommandChannel` runs every call through `run(_:params:on:origin:)`, so each step
    /// the command records is the agent's, and a refused call changes nothing.
    @Test func aRunUnderAnAgentOriginMarksItsSteps() throws {
        let catalog = try #require(FakeCanvasDocument.catalog)
        var doc = FakeCanvasDocument.fixture
        let add = JSONValue.object(["x": .number(1), "y": .number(2), "w": .number(3), "h": .number(4)])
        _ = try catalog.run("history.begin", params: Self.named("AI: Boxes"), on: &doc, origin: Self.claude)
        _ = try catalog.run("rect.add", params: add, on: &doc, origin: Self.claude)
        _ = try catalog.run("rect.add", params: add, on: &doc)
        #expect(doc.history.stepOrigins == [.agent(client: "claude", request: "AI: Boxes"), .user])
        #expect(StepOrigin.current == .user)
        let before = doc
        #expect(throws: CatalogError.self) { try catalog.run("rect.nope", params: .object([:]), on: &doc, origin: Self.claude) }
        #expect(doc.history == before.history)
    }
}
