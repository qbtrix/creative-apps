// HelpReports.swift (report-problem RP-5): the CLI's Help provider. A `.suitehelp` file names the app and may hold
// what the sheet reads on a Mac: the version, build, macOS and model, the crash files and the home, user and host
// names to redact. A value the file leaves out is this machine's, read as the sheet reads it (SuiteModel's ThisMac
// and CrashFolderReader), so `afterglow suite new --json '{"app":"photo"}'` then `help.report-problem` reports
// this Mac's recent Photo crashes; a fixture that lists `crashes` reads no crash folder. Never the network.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel
import SuiteModel

/// SuiteModel's `ProblemReport` and `BetaNotes`, built from a `.suitehelp` file's values.
public struct HelpReports: HelpProviding, Hashable {
    public var version, build, macOS, model: String
    public var crashes: [CrashFile]
    public var now: Date
    public var home, user, host: String

    public init(version: String, build: String, macOS: String, model: String, crashes: [CrashFile], now: Date,
                home: String, user: String, host: String) {
        (self.version, self.build, self.macOS, self.model, self.crashes) = (version, build, macOS, model, crashes)
        (self.now, self.home, self.user, self.host) = (now, home, user, host)
    }

    /// The report's fields and its text, the shape the sheet's provider answers with.
    public func report(app: String, note: String) -> JSONValue {
        let report = ProblemReport.build(app: SuiteApp(rawValue: app) ?? .launcher, version: version, build: build, macOS: macOS,
                                         model: model, crashes: crashes, now: now, home: home, user: user, host: host)
        return SuiteHelpCatalog.reportAnswer(report, text: report.text(note: note))
    }

    public func betaNotes() -> JSONValue { SuiteHelpCatalog.notesAnswer(BetaNotes.current) }

    /// A `.suitehelp` file. Every field but `app` may be left out; a saved document's `answer` is ignored.
    struct File: Codable {
        struct Crash: Codable { var name: String; var modified: Date; var text: String }
        var app: String
        var version, build, macOS, model, home, user, host: String?
        var now: Date?
        var crashes: [Crash]?
    }

    /// `self` as a `.suitehelp` file for `app`.
    public func file(app: String) throws -> Data {
        let file = File(app: app, version: version, build: build, macOS: macOS, model: model, home: home, user: user,
                        host: host, now: now, crashes: crashes.map { File.Crash(name: $0.name, modified: $0.modified, text: $0.text) })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(file)
    }

    /// The document in a `.suitehelp` file. Throws when it isn't one or names an app the suite doesn't have.
    static func open(_ data: Data) throws -> SuiteHelpDocument {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try document(decoder.decode(File.self, from: data))
    }

    /// A new document for `options`' app, reading this Mac: `{"app": "photo"}`.
    static func new(_ options: JSONValue) throws -> SuiteHelpDocument { try document(options.decode(File.self)) }

    /// A file naming an app the suite doesn't have.
    struct UnknownApp: Error, CustomStringConvertible {
        let name: String
        var description: String { "the suite has no app \(name); name one of \(SuiteApp.allCases.map(\.rawValue).joined(separator: ", "))" }
    }

    static func document(_ file: File) throws -> SuiteHelpDocument {
        guard SuiteApp(rawValue: file.app) != nil else { throw UnknownApp(name: file.app) }
        let now = file.now ?? Date(), home = file.home ?? ThisMac.home
        let crashes = file.crashes.map { $0.map { CrashFile(name: $0.name, modified: $0.modified, text: $0.text) } }
            ?? CrashFolderReader.read(arguments: [], home: home, now: now)
        let reports = HelpReports(
            version: file.version ?? ThisMac.version, build: file.build ?? ThisMac.build, macOS: file.macOS ?? ThisMac.macOS,
            model: file.model ?? ThisMac.model, crashes: crashes, now: now, home: home,
            user: file.user ?? ThisMac.user, host: file.host ?? ThisMac.host)
        return SuiteHelpDocument(app: file.app, provider: reports)
    }
}
