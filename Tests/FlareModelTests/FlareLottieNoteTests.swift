// FlareLottieNoteTests.swift: the import note a Lottie open leaves above the stage (FlareLottieNote.swift), feature
// lottie-open LO-4 (docs/blueprints/flare/features/lottie-open.md): a landed open shows one row per skipped part (or
// that nothing was skipped), opens untitled, Dismiss and the next load clear it, a refused open keeps the open
// document and says why; a long list shows its first few and counts the rest; a .json path routes to the Lottie open, from the panel or a drop. Runs on Linux and macOS.
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
        let noted = workspace
        workspace.dismissImportNote()
        #expect(workspace.importNote == nil)
        #expect(workspace != noted, "== must see the note go, or the window's @State skips the redraw and it stays up")
        #expect(workspace.importNoteRows.isEmpty)
        #expect(workspace.document == FlareFixtures.bounce, "Dismiss closes the note, not the document")
        workspace.finishLottieOpen(.success((FlareFixtures.bounce, skipped)))
        workspace.newDocument()
        #expect(workspace.importNote == nil, "a new document keeps an old Lottie's note")
    }

    @Test func aRefusedOpenKeepsTheDocumentAndSaysWhy() {
        var workspace = FlareWorkspace(services: .fake())
        workspace.newDocument()
        let before = workspace.document
        workspace.beginOpen()
        workspace.finishLottieOpen(.failure(.notYet))
        #expect(workspace.loadState == .failed("Opening Lottie arrives with LO-3."))
        #expect(workspace.document == before)
        #expect(workspace.importNote == nil)
    }

    @Test func aJSONPathOpensAsLottie() {
        #expect(FlareWorkspace.opensAsLottie("/tmp/bounce.json"))
        #expect(FlareWorkspace.opensAsLottie("/tmp/Bounce.JSON"))
        #expect(!FlareWorkspace.opensAsLottie("/tmp/bounce.flare"))
        #expect(!FlareWorkspace.opensAsLottie("/tmp/json"))
    }

    @Test func aLongSkipListShowsTheFirstFewAndCountsTheRest() {
        var workspace = FlareWorkspace(services: .fake())
        let many = (1...12).map { "The image \"Photo \($0)\" isn't supported yet and was left out." }
        workspace.finishLottieOpen(.success((FlareFixtures.bounce, many)))
        let shown = FlareWorkspace.importNoteMaxRows
        #expect(workspace.importNote == many, "the Model keeps every skipped part")
        #expect(workspace.importNoteRows.count == shown + 1, "the note grows with the file and pushes the stage down")
        #expect(Array(workspace.importNoteRows.prefix(shown)) == Array(many.prefix(shown)))
        #expect(workspace.importNoteRows.last == "\(many.count - shown) more parts were left out.")
        let exact = Array(many.prefix(shown + 1))
        workspace.finishLottieOpen(.success((FlareFixtures.bounce, exact)))
        #expect(workspace.importNoteRows == exact, "one extra part shows as itself, not as \"1 more\"")
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
