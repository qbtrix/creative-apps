// CommandFakeTests.swift (command-catalog CC-2, CJ0): the fake's ids and fixture answer like the fake,
// and each app Model's `<X>Headless` stub refuses with `notBuilt` naming its adopting slice.
import Foundation
import Testing
import SuiteKernel

@Suite struct CommandFakeTests {
    /// The six commands, undo and redo, the five file-flow commands and the eight fill commands, sorted, each with its kind and an example on the fixture.
    @Test func fakeListsItsCommands() throws {
        let catalog = FakeCanvasDocument.catalog
        #expect(catalog.app == "fake")
        #expect(catalog.ids == ["doc.export-json", "edit.redo", "edit.undo", "file.clear-recent", "file.drop", "file.open-in",
                              "file.open-recent", "file.recent", "fill.angle", "fill.gradient", "fill.read", "fill.stop-add",
                              "fill.stop-color", "fill.stop-move", "fill.stop-remove", "fill.type", "rect.add", "rect.list", "rect.move", "rect.remove", "rect.select"])
        let kinds = Dictionary(uniqueKeysWithValues: catalog.describeAll().map { ($0.id, $0.kind) })
        #expect(kinds == ["rect.add": .edit, "rect.move": .edit, "rect.remove": .edit, "rect.select": .view, "rect.list": .query,
                          "doc.export-json": .file, "edit.undo": .view, "edit.redo": .view, "file.recent": .query,
                          "file.open-recent": .file, "file.clear-recent": .view, "file.open-in": .file, "file.drop": .file, "fill.read": .query]
                          .merging(GradientCommands.specs(FakeCanvasDocument.self).filter { $0.id != "fill.read" }.map { ($0.id, .edit) }) { $1 })
        #expect(catalog.describe("rect.add")?.title == "Add Rectangle" && catalog.spec("rect.add")?.params == FakeCanvasDocument.AddRect.paramSchema)
        #expect(try catalog.describe("rect.add")?.example.decode(FakeCanvasDocument.AddRect.self).w == 30)
        #expect(CommandCatalog<FakeCanvasDocument>.empty(app: "x").ids.isEmpty)
    }

    /// The fixture: Rect 1 selected and free, Rect 2 locked; availability says why not in the app's words.
    @Test func fixtureAndAvailability() throws {
        let fixture = FakeCanvasDocument.fixture, catalog = FakeCanvasDocument.catalog
        #expect(fixture.rects.map(\.name) == ["Rect 1", "Rect 2"] && fixture.rects.map(\.locked) == [false, true] && fixture.selected?.id == 1)
        #expect(catalog.availability("rect.move", on: fixture) == .available && catalog.availability("edit.undo", on: fixture).why == "There is nothing to undo.")
        #expect(catalog.availability("rect.remove", on: FakeCanvasDocument()).why == "Select a rectangle first.")
        var locked = fixture
        try locked.select(2)
        #expect(catalog.availability("rect.move", on: locked).why == "Unlock Rect 2 first.")
        #expect(throws: CatalogError.unavailable(id: "rect.remove", why: "Unlock Rect 2 first.")) { try locked.remove() }
        #expect(locked.rects == fixture.rects && locked.history.canUndo == false)
        #expect(throws: CatalogError.self) { try locked.select(9) }
    }

    /// Each edit records one named step, a drag folds into one, undo restores the saved bytes, save then open is equal.
    @Test func editsUndoAndSaveLikeTheFake() throws {
        var doc = FakeCanvasDocument.fixture
        let saved = try doc.save()
        #expect(doc.add(.init(x: 1, y: 2, w: 3, h: 4, name: nil)).name == "Rect 3" && doc.history.undoName == "Add Rectangle")
        _ = try doc.move(.init(dx: 5, dy: 0, drag: "d1")); _ = try doc.move(.init(dx: 5, dy: 1, drag: "d1"))
        #expect(doc.rects.last?.x == 11 && doc.history.steps == ["Add Rectangle", "Move Rectangle"])
        try doc.remove()
        #expect(doc.rects.count == 2 && doc.selection == nil && doc.history.undoName == "Remove Rectangle")
        #expect(doc.step(redo: false) && doc.step(redo: false) && doc.step(redo: false) && !doc.step(redo: false))
        #expect(try doc.save() == saved && doc.step(redo: true) && doc.rects.count == 3)
        #expect(try FakeCanvasDocument.open(doc.save(), name: "a.fake").rects == doc.rects)
        #expect(try doc.export("json", options: .null) == [ExportedFile(suggestedName: "canvas.json", format: "json", data: doc.save())])
        #expect(throws: CatalogError.self) { try doc.export("png", options: .null) }
        #expect(FakeCanvasDocument.fixture.summary() == .object(["rects": .number(2), "selected": .string("Rect 1")]))
    }

    /// Each app's stub is declared in its Model and refuses `open` with `notBuilt` naming its adopting slice.
    /// SuiteKernelTests links only SuiteKernel (Package.swift), so this reads each stub's source.
    @Test(arguments: ["Photo", "Design", "Flare", "Halo", "Library"])
    func headlessStubThrowsNotBuilt(app: String) throws {
        let file = KernelShapeTests.kernelSources.deletingLastPathComponent()
            .appendingPathComponent("\(app)Model").appendingPathComponent("\(app)Headless.swift")
        let text = try String(contentsOf: file, encoding: .utf8)
        #expect(text.contains("public struct \(app)Headless: HeadlessDocument {"))
        guard text.contains("command-catalog CC-2 stub") else { return } // its adopting slice has filled it
        #expect(text.contains("public static let adoptingSlice = \"adopt-command-catalog AC-\(app.lowercased())\""))
        #expect(text.contains("public static let app = \"\(app.lowercased())\""))
        #expect(text.contains("static func open(_ data: Data, name: String) throws -> \(app)Headless { throw notBuilt(\"open\") }"))
        #expect(text.contains("static func notBuilt(_ id: String) -> CatalogError { .notBuilt(id: id, feature: adoptingSlice) }"))
    }
}
