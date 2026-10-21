// SuiteHelpCatalogTests.swift (report-problem RP-1, written first; RP-5 turns the runs on): the suite's Help
// catalog keeps its ledger now; its runs hand the provider's report and notes back, and Welcome runs only in
// the launcher. Linux-safe.
import Foundation
import SuiteKernel
import Testing

/// A provider that answers with what it was asked, so a run's result shows the params reached it.
struct EchoHelp: HelpProviding {
    func report(app: String, note: String) -> JSONValue { .object(["app": .string(app), "text": .string(note)]) }
    func betaNotes() -> JSONValue { .object(["notes": .array([.object(["title": .string("T"), "detail": .string("D")])])]) }
}

@Suite struct SuiteHelpCatalogTests {
    static let catalog = SuiteHelpCatalog.catalog

    @Test func idsKeepTheLedger() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let ledger = try String(contentsOf: url.appendingPathComponent("command-ids/suite.txt"), encoding: .utf8)
        #expect(catalog.app == "suite")
        #expect(catalog.ids == ["help.beta-notes", "help.report-problem", "help.welcome"])
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

    @Test(.disabled("waits on RP-5")) func reportReturnsTheProvidersReport() throws {
        var doc = SuiteHelpDocument(app: "launcher", provider: EchoHelp())
        let out = try catalog.run("help.report-problem", params: .object(["app": .string("photo"), "note": .string("hi")]), on: &doc)
        #expect(out.result == .object(["app": .string("photo"), "text": .string("hi")]))
        #expect(out.undoStep == nil)
    }

    @Test(.disabled("waits on RP-5")) func reportDefaultsToTheDocumentsApp() throws {
        var doc = SuiteHelpDocument(app: "halo", provider: EchoHelp())
        let out = try catalog.run("help.report-problem", params: .object([:]), on: &doc)
        #expect(out.result == .object(["app": .string("halo"), "text": .string("")]))
    }

    @Test(.disabled("waits on RP-5")) func betaNotesReturnsTheProvidersNotes() throws {
        var doc = SuiteHelpDocument(app: "photo", provider: EchoHelp())
        #expect(try catalog.run("help.beta-notes", params: .object([:]), on: &doc).result == EchoHelp().betaNotes())
    }

    @Test func welcomeRunsOnlyInTheLauncher() {
        #expect(catalog.availability("help.welcome", on: SuiteHelpDocument(app: "launcher", provider: EchoHelp())) == .available)
        #expect(catalog.availability("help.welcome", on: SuiteHelpDocument(app: "photo", provider: EchoHelp())).why != nil)
    }
}
