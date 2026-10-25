// ProblemReport.swift (report-problem RP-1 stubs, RP-4 bodies): what Help > Report a Problem… shows and the
// person sends: the app, its version and build, macOS, the Mac model and the newest suite crashes, trimmed and
// redacted. Built from values the caller reads; this file never reads a disk or a network. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// One crash file from the crash folder: its file name, when it was written and its text.
public struct CrashFile: Hashable, Sendable {
    public var name: String
    public var modified: Date
    public var text: String
    public init(name: String, modified: Date, text: String) { (self.name, self.modified, self.text) = (name, modified, text) }
}

/// A problem report: the app and system it came from and its crashes, ready to read as plain text.
public struct ProblemReport: Hashable, Sendable, Codable {
    /// The app's display name, its version and build, the macOS version and the Mac model.
    public var app, version, build, macOS, model: String
    /// The crashes: trimmed, redacted, newest first, at most 3.
    public var crashes: [String]
    /// The home path, user and host `text(note:)` also redacts from the note. Never encoded, so the report's
    /// JSON can't carry them, and never compared.
    private var redaction = CrashRedaction()

    private enum CodingKeys: String, CodingKey { case app, version, build, macOS, model, crashes }

    public init(app: String, version: String, build: String, macOS: String, model: String, crashes: [String]) {
        (self.app, self.version, self.build, self.macOS, self.model, self.crashes) = (app, version, build, macOS, model, crashes)
    }

    /// The report for `app`: the newest three of `crashes` from suite processes at most 7 days before `now`, each
    /// trimmed to its header and crashed thread, with `home`, `user` and `host` redacted.
    public static func build(app: SuiteApp, version: String, build: String, macOS: String, model: String,
                             crashes: [CrashFile], now: Date, home: String, user: String, host: String) -> ProblemReport {
        let redaction = CrashRedaction(home: home, user: user, host: host)
        let suite = Set(SuiteApp.allCases.map(\.displayName))
        let picked = crashes
            .filter { $0.name.hasSuffix(".ips") && suite.contains(CrashTrim.process(of: $0)) }
            .filter { now.timeIntervalSince($0.modified) <= 7 * 86_400 }
            .sorted { $0.modified > $1.modified }
            .prefix(3)
            .map { redaction.apply($0.name + "\n" + CrashTrim.trim($0.text)) }
        var report = ProblemReport(app: app.displayName, version: version, build: build, macOS: macOS, model: model,
                                   crashes: picked)
        report.redaction = redaction
        return report
    }

    /// The note, then the report, as plain text, redacted.
    public func text(note: String) -> String {
        var parts = note.isEmpty ? [] : [note]
        parts.append("\(app) \(version) (\(build))\nmacOS \(macOS)\nMac \(model)")
        if crashes.isEmpty {
            parts.append("No crash reports from AfterGlow in the last 7 days.")
        } else {
            parts.append("Crashes (\(crashes.count), newest first):")
            parts += crashes
        }
        return redaction.apply(parts.joined(separator: "\n\n"))
    }
}

/// Replaces the home path with `~` and the host and user names with `<host>` and `<user>`, every occurrence, in
/// any case. The longer name goes first, so a host that holds the user name ("testers-mac") reads as `<host>`.
struct CrashRedaction: Hashable, Sendable {
    var terms: [(find: String, with: String)] = []

    init() {}

    init(home: String, user: String, host: String) {
        let home = home.hasSuffix("/") ? String(home.dropLast()) : home
        let names = [(user, "<user>"), (host, "<host>")].sorted { $0.0.count > $1.0.count }
        terms = ([(home, "~")] + names).filter { !$0.0.isEmpty }.map { (find: $0.0, with: $0.1) }
    }

    func apply(_ text: String) -> String {
        terms.reduce(text) { text, term in text.replacing(Regex<Substring>(verbatim: term.find).ignoresCase(), with: term.with) }
    }

    // Never part of a report's identity: two reports with the same fields are the same report.
    static func == (lhs: Self, rhs: Self) -> Bool { true }
    func hash(into hasher: inout Hasher) {}
}

/// An `.ips` crash file is a JSON header line, then a JSON body. The trim keeps the header and, from the body,
/// the process path, the exception and the crashed thread's frames.
enum CrashTrim {
    struct Header: Decodable { var app_name: String?; var name: String? }
    struct Exception: Codable { var type, signal, subtype: String? }
    struct Frame: Codable { var symbol, sourceFile: String?; var imageIndex, imageOffset, sourceLine: Int? }
    struct Thread: Codable { var triggered: Bool?; var frames: [Frame]? }
    struct Body: Decodable { var procPath: String?; var exception: Exception?; var faultingThread: Int?; var threads: [Thread]? }
    struct Trimmed: Encodable { var procPath: String?; var exception: Exception?; var crashedThread: Int?; var frames: [Frame] }

    /// Split into the header line and the body.
    static func split(_ text: String) -> (header: Substring, body: Substring) {
        guard let newline = text.firstIndex(of: "\n") else { return (text[...], "") }
        return (text[..<newline], text[text.index(after: newline)...])
    }

    /// The crashing process: the header's app name, else the file name before its first "-".
    static func process(of file: CrashFile) -> String {
        let header = try? JSONDecoder().decode(Header.self, from: Data(split(file.text).header.utf8))
        return header?.app_name ?? header?.name ?? String(file.name.prefix { $0 != "-" })
    }

    /// The header line and the trimmed body; a body that isn't `.ips` JSON keeps its first 60 lines.
    static func trim(_ text: String) -> String {
        let (header, rest) = split(text)
        guard let body = try? JSONDecoder().decode(Body.self, from: Data(rest.utf8)) else {
            return String(header) + "\n" + rest.split(separator: "\n", omittingEmptySubsequences: false).prefix(60).joined(separator: "\n")
        }
        let threads = body.threads ?? []
        let index = threads.firstIndex { $0.triggered == true }
            ?? body.faultingThread.flatMap { threads.indices.contains($0) ? $0 : nil }
        let frames = index.map { threads[$0].frames ?? [] } ?? []
        let trimmed = Trimmed(procPath: body.procPath, exception: body.exception, crashedThread: index, frames: frames)
        let encoder = JSONEncoder()
        // Slashes stay unescaped, so the home path in procPath and sourceFile still matches its redaction.
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        let json = (try? encoder.encode(trimmed)).map { String(decoding: $0, as: UTF8.self) } ?? ""
        return String(header) + "\n" + json
    }
}
