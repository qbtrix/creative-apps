// FlareLottieNoteTests.swift: the import note a Lottie open leaves above the stage (FlareLottieNote.swift), feature
// lottie-open LO-4 (docs/blueprints/flare/features/lottie-open.md): a landed open shows one row per skipped part (or
// that nothing was skipped), opens untitled, Dismiss and the next load clear it, a refused open keeps the open
// document and says why; a .json path routes to the Lottie open, from the panel or a drop. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
@testable import FlareModel
import SuiteKernel
import Testing

private let skipped = [
    "The precomp \"Logo\" isn't supported yet and was left out.",
    "The image \"Photo\" isn't supported yet and was left out.",
]

@Suite struct FlareLottieNoteTests {
    @Test func aLandedOpenShowsOneRowPerSkippedPartAndOpensUntitled() throws {
        var workspace = FlareWorkspace(services: .fake())
        workspace.beginOpen()
        workspace.finishLottieOpen(.success((FlareFixtures.bounce, skipped)))
        #expect(workspace.document == FlareFixtures.bounce)
        #expect(workspace.importNote == skipped)
        #expect(workspace.importNoteRows == skipped)
        #expect(workspace.fileName == nil, "a Lottie opens untitled, so Save never targets the JSON")
        #expect(workspace.loadState == .idle)
    }

    @Test func nothingSkippedStillSaysSo() {
        var workspace = FlareWorkspace(services: .fake())
        #expect(workspace.importNoteRows.isEmpty, "no note before a Lottie open")
        workspace.finishLottieOpen(.success((FlareFixtures.bounce, [])))
        #expect(workspace.importNoteRows == [FlareWorkspace.nothingSkipped])
        #expect(FlareWorkspace.nothingSkipped == "Nothing was skipped.")
    }

    @Test func dismissAndTheNextLoadClearTheNote() throws {
        var workspace = FlareWorkspace(services: .fake())
        workspace.finishLottieOpen(.success((FlareFixtures.bounce, skipped)))
        workspace.dismissImportNote()
        #expect(workspace.importNote == nil)
        #expect(workspace.importNoteRows.isEmpty)
        #expect(workspace.document == FlareFixtures.bounce, "Dismiss closes the note, not the document")
        workspace.finishLottieOpen(.success((FlareFixtures.bounce, skipped)))
        workspace.newDocument()
        #expect(workspace.importNote == nil, "a new document keeps an old Lottie's note")
    }

    /// LO-5: `import.report` reads the last Lottie open's skipped sentences, after Dismiss too; with no Lottie
    /// open it is unavailable and says why.
    @Test func importReportListsWhatTheLastLottieOpenSkipped() throws {
        var workspace = FlareWorkspace(services: .fake())
        let id = "import.report", catalog = FlareWorkspace.catalog
        #expect(catalog.availability(id, on: workspace).why == FlareWorkspace.noLottieOpened)
        #expect(FlareWorkspace.noLottieOpened == "Nothing was opened from a Lottie file.")
        workspace.finishLottieOpen(.success((FlareFixtures.bounce, skipped)))
        workspace.dismissImportNote()
        let report = try catalog.run(id, params: .object([:]), on: &workspace).result
        #expect(report == .object(["skipped": .array(skipped.map(JSONValue.string))]), "Dismiss keeps the report")
        workspace.newDocument()
        #expect(catalog.availability(id, on: workspace).why == FlareWorkspace.noLottieOpened, "a new document keeps the report")
        workspace.finishLottieOpen(.success((FlareFixtures.bounce, [])))
        #expect(try catalog.run(id, params: .object([:]), on: &workspace).result == .object(["skipped": .array([])]))
    }

    /// The headless open (`openLottie`, the CLI's and `file.open`'s) leaves the report too.
    @Test func theHeadlessOpenLeavesTheReport() throws {
        let file = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Lottie/precomp.lottie.json")
        var workspace = FlareWorkspace(services: .fake())
        let sentences = try workspace.openLottie(try Data(contentsOf: file), named: "precomp.json")
        #expect(sentences.count == 2)
        #expect(workspace.importReport == sentences)
        #expect(try FlareWorkspace.catalog.run("import.report", params: .object([:]), on: &workspace).result
            == .object(["skipped": .array(sentences.map(JSONValue.string))]))
    }

    @Test func aRefusedOpenKeepsTheDocumentAndSaysWhy() {
        var workspace = FlareWorkspace(services: .fake())
        workspace.newDocument()
        let before = workspace.document
        workspace.beginOpen()
        workspace.finishLottieOpen(.failure(.notLottie))
        #expect(workspace.loadState == .failed("This file isn't a Lottie file."))
        #expect(workspace.document == before)
        #expect(workspace.importNote == nil)
    }

    @Test func aJSONPathOpensAsLottie() {
        #expect(FlareWorkspace.opensAsLottie("/tmp/bounce.json"))
        #expect(FlareWorkspace.opensAsLottie("/tmp/Bounce.JSON"))
        #expect(!FlareWorkspace.opensAsLottie("/tmp/bounce.flare"))
        #expect(!FlareWorkspace.opensAsLottie("/tmp/json"))
    }

    @Test func aDroppedJSONRoutesToTheLottieOpenAndTheRestToTheBridge() {
        let actions: [DropAction] = [
            .refuse(path: "/tmp/bounce.json", reason: "AfterGlow can't open .json files."),
            .open(path: "/tmp/Title.flare"),
            .refuse(path: "/tmp/notes.txt", reason: "AfterGlow can't open .txt files."),
            .handOff(path: "/tmp/shot.png", app: "photo"),
        ]
        let (lottie, rest) = FlareWorkspace.lottieDrops(actions)
        #expect(lottie == ["/tmp/bounce.json"])
        #expect(rest == Array(actions.dropFirst()))
    }
}
