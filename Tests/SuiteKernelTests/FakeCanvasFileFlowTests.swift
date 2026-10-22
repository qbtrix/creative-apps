// FakeCanvasFileFlowTests.swift (file-flow SF-9): the fake app takes the five file-flow commands over fixed readers,
// so RJ-X43 (Tests/RealJobs/fake/file-flow/) runs `file.drop` on the CLI before any real app adopts.
import SuiteKernel
import Testing

struct FakeCanvasFileFlowTests {
    /// RJ-X43's three files, in its order: another app's document, content the fake places, a type nobody reads.
    static let paths = ["input/Intro.halo", "input/Sunset.png", "input/notes.xyz"]

    @Test func dropReturnsRJX43sActionsAndPlacesTheImageAsOneStep() throws {
        var doc = FakeCanvasDocument(rects: [FakeRect(id: 1, name: "Rect 1", x: 10, y: 10, w: 100, h: 60)])
        let outcome = try FakeCanvasDocument.catalog.run(
            CommandEnvelope(id: "file.drop", params: .object(["paths": .array(Self.paths.map { .string($0) })])), on: &doc)
        #expect(outcome.result == (try JSONValue(encoding: [
            DropAction.handOff(path: "input/Intro.halo", app: "halo"),
            DropAction.place(path: "input/Sunset.png"),
            DropAction.refuse(path: "input/notes.xyz", reason: "AfterGlow can't open .xyz files."),
        ])))
        #expect(doc.rects.map(\.name) == ["Rect 1", "Sunset.png"] && doc.selection == 2)
        #expect(doc.history.undoName == "Place" && doc.step(redo: false) && doc.rects.map(\.name) == ["Rect 1"])
    }

    @Test func theFakeReadsItsOwnTypeAndListsTheFileFlowSpecs() throws {
        let doc = FakeCanvasDocument()
        #expect(doc.readers(ofExtension: "fake") == ["fake"] && doc.readers(ofExtension: "xyz").isEmpty)
        #expect(DropPlan.plan(["a.fake"], into: "fake", hasDocument: true, places: doc.placesExtensions,
                              readers: doc.readers(ofExtension:)) == [.open(path: "a.fake")])
        for id in ["file.recent", "file.open-recent", "file.clear-recent", "file.open-in", "file.drop"] {
            #expect(FakeCanvasDocument.catalog.spec(id) != nil, "\(id)")
        }
        #expect(doc.recentFiles.isEmpty && doc.openInApps == ["halo"] && doc.openInHelp == nil)
        #expect(FakeCanvasDocument.catalog.availability("file.clear-recent", on: doc) == .unavailable("No Recent Files"))
        var fixture = FakeCanvasDocument.fixture
        _ = try FakeCanvasDocument.catalog.run(CommandEnvelope(id: "file.clear-recent", params: .object([:])), on: &fixture)
        #expect(FakeCanvasDocument.fixture.recentFiles.count == 1 && fixture.recentFiles.isEmpty)
    }

    @Test func theOldCommandsAreUnchanged() {
        let ids = FakeCanvasDocument.catalog.describeAll().map(\.id)
        #expect(Set(ids).isSuperset(of: ["rect.add", "rect.move", "rect.remove", "rect.select", "rect.list", "doc.export-json",
                                         "edit.undo", "edit.redo"]) && ids.count == 21)
    }
}
