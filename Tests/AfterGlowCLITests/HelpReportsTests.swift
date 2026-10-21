// HelpReportsTests.swift (report-problem RP-5, written first): `afterglow suite help.report-problem` reads a
// `.suitehelp` file (the Mac's fields, its crash files and the names to redact) and answers with the same text
// the sheet shows, which is SuiteModel's ProblemReport for those values. Linux-safe; files live in a FakeIO.
import AfterGlowCLICore
import Foundation
import SuiteModel
import Testing

@Suite struct HelpReportsTests {
    static let now = Date(timeIntervalSince1970: 1_792_000_000)

    /// An `.ips` file from `process`: a header line, then a body whose crashed thread's one frame is `marker`.
    static func ips(_ process: String, _ marker: String) -> String {
        #"{"app_name":"\#(process)","name":"\#(process)"}"# + "\n"
            + #"{"procPath":"/Users/tester/Applications/\#(process).app","threads":[{"triggered":true,"frames":[{"symbol":"\#(marker)"}]}]}"#
    }

    static let reports = HelpReports(
        version: "0.9", build: "42", macOS: "26.1", model: "Mac15,3",
        crashes: [CrashFile(name: "Photo-older.ips", modified: now - 7200, text: ips("Photo", "older")),
                  CrashFile(name: "Browser-1.ips", modified: now - 60, text: ips("Browser", "web")),
                  CrashFile(name: "Photo-newer.ips", modified: now - 3600, text: ips("Photo", "newer")),
                  CrashFile(name: "Halo-stale.ips", modified: now - 10 * 86_400, text: ips("Halo", "stale"))],
        now: now, home: "/Users/tester", user: "tester", host: "testers-mac")

    /// The sheet's text for these values.
    static func sheet(note: String) -> String {
        ProblemReport.build(app: .photo, version: "0.9", build: "42", macOS: "26.1", model: "Mac15,3",
                            crashes: reports.crashes, now: now, home: "/Users/tester", user: "tester", host: "testers-mac")
            .text(note: note)
    }

    /// Runs `afterglow <arguments>` over `io` and reads back its exit code and its one stdout object.
    static func run(_ arguments: [String], _ io: FakeIO) throws -> (Int32, [String: JSONValue]) {
        let code = CLI.run(arguments, io: io)
        guard case .object(let fields) = try JSONValue(json: Data((io.stdout.last ?? "").utf8)) else { return (code, [:]) }
        return (code, fields)
    }

    @Test func theProvidersReportIsTheSheets() {
        guard case .object(let report) = Self.reports.report(app: "photo", note: "It froze.") else {
            Issue.record("not an object"); return
        }
        #expect(report["text"] == .string(Self.sheet(note: "It froze.")))
        #expect(report["app"] == .string("Photo"))
        guard case .array(let crashes)? = report["crashes"] else { Issue.record("no crashes"); return }
        #expect(crashes.count == 2, "only the two recent Photo crashes")
    }

    @Test func theCLIReportsFromAFileWithTheSheetsText() throws {
        let io = FakeIO(files: ["in.suitehelp": try Self.reports.file(app: "photo")])
        let (code, out) = try Self.run(["suite", "help.report-problem", "--in", "in.suitehelp", "--out", "out.suitehelp",
                                        "--json", #"{"note":"It froze."}"#], io)
        #expect(code == 0, "\(io.stderr)")
        guard case .object(let result)? = out["result"], case .string(let text)? = result["text"] else {
            Issue.record("no text in \(out)"); return
        }
        #expect(text == Self.sheet(note: "It froze."))
        if let newer = text.range(of: "newer"), let older = text.range(of: "older") {
            #expect(newer.lowerBound < older.lowerBound, "newest first")
        } else { Issue.record("a Photo crash is missing") }
        let printed = io.stdout.joined()
        for leak in ["tester", "/Users/", "Browser", "stale"] { #expect(!printed.contains(leak), "\(leak) leaks") }
        #expect(try JSONValue(json: try io.read("out.suitehelp")) == .object(["app": .string("photo"), "answer": .object(result)]))
    }

    @Test func betaNotesListTheBuildsNotes() throws {
        let io = FakeIO(files: ["in.suitehelp": try Self.reports.file(app: "photo")])
        let (code, out) = try Self.run(["suite", "help.beta-notes", "--in", "in.suitehelp", "--out", "o.suitehelp"], io)
        #expect(code == 0, "\(io.stderr)")
        guard case .object(let result)? = out["result"], case .array(let notes)? = result["notes"] else {
            Issue.record("no notes in \(out)"); return
        }
        #expect(notes.count == BetaNotes.current.count)
        #expect(notes.first == .object(["title": .string("This is a beta"), "detail": .string(BetaNotes.current.first?.detail ?? "")]))
    }

    @Test func suiteIsListedAndNewMakesAnEmptyRequest() throws {
        let io = FakeIO()
        let (_, apps) = try Self.run(["list-apps"], io)
        let suite = JSONValue.object(["name": .string("suite"), "openExtensions": .array([.string("suitehelp")]), "exportFormats": .array([])])
        guard case .array(let listed)? = apps["apps"] else { Issue.record("no apps"); return }
        #expect(listed.contains(suite))
        #expect(try Self.run(["suite", "new", "--out", "n.suitehelp", "--json", #"{"app":"halo"}"#], io).0 == 0, "\(io.stderr)")
        let (code, opened) = try Self.run(["suite", "open", "n.suitehelp"], io)
        #expect(code == 0)
        #expect(opened["summary"] == .object(["app": .string("halo")]))
    }

    @Test func aFileThatIsNotARequestIsData() throws {
        let io = FakeIO(files: ["bad.suitehelp": Data("not json".utf8), "app.suitehelp": Data(#"{"app":"word"}"#.utf8)])
        #expect(try Self.run(["suite", "open", "bad.suitehelp"], io).0 == CLI.Exit.data)
        #expect(try Self.run(["suite", "open", "app.suitehelp"], io).0 == CLI.Exit.data, "an app the suite doesn't have")
    }
}
