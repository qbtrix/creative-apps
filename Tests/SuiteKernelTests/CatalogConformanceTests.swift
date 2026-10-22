// CatalogConformanceTests.swift (command-catalog CC-6): the fake canvas keeps every catalog law, and a document
// whose catalog breaks one law fails with a problem naming the command. Written first by CC-6; CC-8 builds
// `CatalogConformance.check` on CC-7's `CommandCatalog.run` and CC-4's `validate`.
import Foundation
import Testing
import SuiteKernel

/// One broken command a `BrokenList` registers beside its good `item.add` and `edit.undo`.
protocol BrokenLaw: Sendable {
    static var spec: CommandSpec<BrokenList<Self>> { get }
}

/// A headless list of strings whose catalog breaks one law: `Law.spec`.
struct BrokenList<Law: BrokenLaw>: HeadlessDocument {
    struct Item: Codable, Sendable { var name: String }
    static var itemSchema: ParamSchema { .object(["name": .string()], required: ["name"]) }
    var items = ["a"], history = History<[String]>()

    static var app: String { "broken" }
    static var openExtensions: [String] { ["broken"] }
    static var exportFormats: [String] { [] }
    static var catalog: CommandCatalog<BrokenList> {
        (try? CommandCatalog(app: app, [add, undo, Law.spec], history: { $0.history })) ?? .empty(app: app)
    }
    /// A good edit: appends a name and records "Add Item" holding the items before.
    static var add: CommandSpec<BrokenList> {
        .typed("item.add", title: "Add Item", summary: "Adds an item.", kind: .edit, params: Item.self, schema: itemSchema,
               example: .object(["name": .string("b")])) { doc, p in
            doc.history.record("Add Item", doc.items); doc.items.append(p.name); return JSONValue.object([:])
        }
    }
    /// Undo, a view command like the fake's: it moves the history and is not itself a step.
    static var undo: CommandSpec<BrokenList> {
        .typed("edit.undo", title: "Undo", summary: "Undoes the last edit.", kind: .view, params: FakeCanvasDocument.NoParams.self,
               schema: ParamSchema.none, example: .object([:]),
               availability: { $0.history.canUndo ? .available : .unavailable("There is nothing to undo.") }) { doc, _ in
            var current = doc.items
            let moved = doc.history.undo { old in defer { current = old }; return current }
            doc.items = current
            return moved
        }
    }
    /// A broken command's spec on this list: `run` changes it as `Law` says.
    static func edit(_ id: String, kind: CommandKind = .edit, _ run: @escaping @Sendable (inout BrokenList) -> Void) -> CommandSpec<BrokenList> {
        .typed(id, title: "Broken", summary: "Breaks one law.", kind: kind, params: FakeCanvasDocument.NoParams.self,
               schema: ParamSchema.none, example: .object([:])) { doc, _ in run(&doc); return JSONValue.object([:]) }
    }

    static func open(_ data: Data, name: String) throws -> BrokenList { BrokenList(items: try JSONDecoder().decode([String].self, from: data)) }
    static func new(_ options: JSONValue) throws -> BrokenList { BrokenList() }
    func save() throws -> Data { try JSONEncoder().encode(items) }
    func export(_ format: String, options: JSONValue) throws -> [ExportedFile] { [] }
    func summary() -> JSONValue { .object(["items": .number(Double(items.count))]) }
}

/// An edit that changes the items and records no step.
enum NoStep: BrokenLaw { static var spec: CommandSpec<BrokenList<Self>> { BrokenList<Self>.edit("item.append") { $0.items.append("x") } } }
/// An edit that records two steps.
enum TwoSteps: BrokenLaw {
    static var spec: CommandSpec<BrokenList<Self>> {
        BrokenList<Self>.edit("item.twice") { doc in
            doc.history.record("Broken", doc.items); doc.items.append("x"); doc.history.record("Broken", doc.items); doc.items.append("y")
        }
    }
}
/// An edit whose step is not named its title.
enum Misnamed: BrokenLaw {
    static var spec: CommandSpec<BrokenList<Self>> { BrokenList<Self>.edit("item.misname") { $0.history.record("Something Else", $0.items); $0.items.append("x") } }
}
/// An edit that records one step named its title, holding the items after it, so undo can't restore the bytes.
enum UndoKeepsChange: BrokenLaw {
    static var spec: CommandSpec<BrokenList<Self>> { BrokenList<Self>.edit("item.stamp") { $0.items.append("x"); $0.history.record("Broken", $0.items) } }
}
/// A query that changes the items.
enum QueryWrites: BrokenLaw { static var spec: CommandSpec<BrokenList<Self>> { BrokenList<Self>.edit("item.peek", kind: .query) { $0.items.append("x") } } }
/// A view command that changes the items.
enum ViewWrites: BrokenLaw { static var spec: CommandSpec<BrokenList<Self>> { BrokenList<Self>.edit("item.zoom", kind: .view) { $0.items.removeAll() } } }
/// An edit whose example fails its own params schema.
enum BadExample: BrokenLaw {
    static var spec: CommandSpec<BrokenList<Self>> {
        .typed("item.rename", title: "Rename Item", summary: "Renames the first item.", kind: .edit, params: BrokenList<Self>.Item.self,
               schema: BrokenList<Self>.itemSchema, example: .object(["title": .string("b")])) { doc, p in
            doc.history.record("Rename Item", doc.items); doc.items = [p.name] + doc.items.dropFirst(); return JSONValue.object([:])
        }
    }
}

@Suite struct CatalogConformanceTests {
    /// The problems `Law`'s list reports; each must name `id`, and the good `item.add` must not appear.
    func expectFails<Law: BrokenLaw>(_ law: Law.Type, naming id: String, sourceLocation: SourceLocation = #_sourceLocation) {
        let problems = CatalogConformance.check(BrokenList<Law>.self, fixture: BrokenList<Law>())
        #expect(!problems.isEmpty, "\(id) broke a law and passed", sourceLocation: sourceLocation)
        #expect(problems.allSatisfy { $0.contains(id) && !$0.contains("item.add") }, "\(problems)", sourceLocation: sourceLocation)
    }

    /// The fixture has no steps, so `history.jump`'s example refuses as unavailable, the filter the apps' laws use.
    @Test func theFakeConforms() {
        #expect(CatalogConformance.check(FakeCanvasDocument.self, fixture: .fixture)
            == ["history.jump: exampleRuns: the example refused on the fixture: history.jump is unavailable: There are no steps yet."])
    }

    @Test func anEditThatRecordsNoStepFails() { expectFails(NoStep.self, naming: "item.append") }
    @Test func anEditThatRecordsTwoStepsFails() { expectFails(TwoSteps.self, naming: "item.twice") }
    @Test func aStepNotNamedItsTitleFails() { expectFails(Misnamed.self, naming: "item.misname") }
    @Test func undoThatLeavesOtherBytesFails() { expectFails(UndoKeepsChange.self, naming: "item.stamp") }
    @Test func aQueryThatChangesBytesFails() { expectFails(QueryWrites.self, naming: "item.peek") }
    @Test func aViewThatChangesBytesFails() { expectFails(ViewWrites.self, naming: "item.zoom") }
    @Test func anExampleThatFailsValidationFails() { expectFails(BadExample.self, naming: "item.rename") }
}
