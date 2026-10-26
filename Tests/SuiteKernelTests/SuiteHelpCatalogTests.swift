// SuiteHelpCatalogTests.swift (report-problem RP-1, written first; RP-5 turns the runs on): the suite's Help
// catalog keeps its ledger; its runs hand the provider's report and notes back and keep the answer for save, and
// Welcome runs only in the launcher. Linux-safe.
import Foundation
import SuiteKernel
import Testing

/// A provider that answers with what it was asked, so a run's result shows the params reached it.
struct EchoHelp: HelpProviding {
    func report(app: String, note: String) -> JSONValue { .object(["app": .string(app), "text": .string(note)]) }
    func betaNotes() -> JSONValue { .object(["notes": .array([.object(["title": .string("T"), "detail": .string("D")])])]) }
}

@Suite struct SuiteHelpCatalogTests {
    let catalog = SuiteHelpCatalog.catalog

    @Test func idsKeepTheLedger() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let ledger = try String(contentsOf: url.appendingPathComponent("command-ids/suite.txt"), encoding: .utf8)
        #expect(catalog.app == "suite")
        #expect(catalog.ids == ["help.beta-notes", "help.connect-assistant", "help.install-cli", "help.report-problem", "help.welcome"])
        #expect(CommandIDLedger.check(catalog.ids, ledger: ledger).isEmpty)
        let listed = Set(ledger.split(whereSeparator: \.isNewline).map(String.init))
        #expect(Set(catalog.ids).subtracting(listed).isEmpty)
    }

    @Test func specsAreQueriesWithTheirParams() {
        #expect(catalog.spec("help.report-problem")?.kind == .query)
        #expect(catalog.spec("help.beta-notes")?.kind == .query)
        let report = catalog.spec("help.report-problem")
        #expect(report?.params.validate(.object(["app": .string("photo"), "note": .string("x")])).isEmpty == true)
        #expect(report?.params.validate(.object([:])).isEmpty == true, "app and note are optional")
        #expect(report?.params.validate(.object(["app": .string("word")])).isEmpty == false)
    }

    /// Every suite app can be reported on, and the note holds 10,000 characters, not one more (#4668).
    @Test func reportAcceptsEveryAppAndANoteUpToItsLimit() throws {
        let report = try #require(catalog.spec("help.report-problem"))
        for app in ["launcher", "flare", "design", "photo", "library", "halo"] {
            #expect(report.params.validate(.object(["app": .string(app)])).isEmpty, "\(app) can't be reported on")
        }
        #expect(report.params.validate(.object(["note": .string(String(repeating: "a", count: 10_000))])).isEmpty)
        #expect(!report.params.validate(.object(["note": .string(String(repeating: "a", count: 10_001))])).isEmpty)
    }

    /// One mapping for both providers (#4667): a report's encoded fields plus its text, and the notes as
    /// title and detail objects.
    @Test func answersAreOneShapeForEveryProvider() throws {
        struct Fields: Encodable { let app = "Photo", crashes = ["c"] }
        #expect(SuiteHelpCatalog.reportAnswer(Fields(), text: "t")
            == .object(["app": .string("Photo"), "crashes": .array([.string("c")]), "text": .string("t")]))
        #expect(SuiteHelpCatalog.notesAnswer([(title: "T", detail: "D")])
            == .object(["notes": .array([.object(["title": .string("T"), "detail": .string("D")])])]))
    }

    @Test func reportReturnsTheProvidersReport() throws {
        var doc = SuiteHelpDocument(app: "launcher", provider: EchoHelp())
        let out = try catalog.run("help.report-problem", params: .object(["app": .string("photo"), "note": .string("hi")]), on: &doc)
        #expect(out.result == .object(["app": .string("photo"), "text": .string("hi")]))
        #expect(out.undoStep == nil)
        #expect(doc.answer == out.result, "the run keeps its answer for save")
    }

    @Test func reportDefaultsToTheDocumentsApp() throws {
        var doc = SuiteHelpDocument(app: "halo", provider: EchoHelp())
        let out = try catalog.run("help.report-problem", params: .object([:]), on: &doc)
        #expect(out.result == .object(["app": .string("halo"), "text": .string("")]))
    }

    @Test func betaNotesReturnsTheProvidersNotes() throws {
        var doc = SuiteHelpDocument(app: "photo", provider: EchoHelp())
        #expect(try catalog.run("help.beta-notes", params: .object([:]), on: &doc).result == EchoHelp().betaNotes())
    }

    @Test func saveWritesTheAppAndTheLastAnswer() throws {
        var doc = SuiteHelpDocument(app: "photo", provider: EchoHelp())
        _ = try catalog.run("help.report-problem", params: .object(["note": .string("n")]), on: &doc)
        let saved = try JSONValue(json: try doc.save())
        #expect(saved == .object(["app": .string("photo"), "answer": .object(["app": .string("photo"), "text": .string("n")])]))
    }

    @Test func welcomeOpensNothingHeadless() {
        var doc = SuiteHelpDocument(app: "launcher", provider: EchoHelp())
        #expect(throws: CatalogError.self) { try catalog.run("help.welcome", params: .object([:]), on: &doc) }
    }

    /// cli-bundle CB-2: the assistant commands need a bundle, which a provider without one doesn't name.
    @Test func assistantCommandsNeedABundle() {
        let doc = SuiteHelpDocument(app: "launcher", provider: EchoHelp())
        #expect(catalog.spec("help.connect-assistant")?.kind == .query)
        #expect(catalog.availability("help.connect-assistant", on: doc).why?.contains("--bundle") == true)
        #expect(catalog.availability("help.install-cli", on: doc).why?.contains("--bundle") == true)
        let install = catalog.spec("help.install-cli")
        #expect(install?.params.validate(.object(["confirm": .bool(true)])).isEmpty == true)
        #expect(install?.params.validate(.object([:])).isEmpty == true, "confirm is optional")
        #expect(install?.params.validate(.object(["confirm": .string("yes")])).isEmpty == false)
    }

    @Test func welcomeRunsOnlyInTheLauncher() {
        #expect(catalog.availability("help.welcome", on: SuiteHelpDocument(app: "launcher", provider: EchoHelp())) == .available)
        #expect(catalog.availability("help.welcome", on: SuiteHelpDocument(app: "photo", provider: EchoHelp())).why != nil)
    }

    @Test func planAnswerLeavesOutNilFields() {
        #expect(SuiteHelpCatalog.planAnswer(plan: "link", at: "/h/a", to: "/b", reason: nil, linked: true)
            == .object(["plan": .string("link"), "at": .string("/h/a"), "to": .string("/b"), "linked": .bool(true)]))
        #expect(SuiteHelpCatalog.planAnswer(plan: "refuse", at: nil, to: nil, reason: "no", linked: false)
            == .object(["plan": .string("refuse"), "reason": .string("no"), "linked": .bool(false)]))
    }
}
