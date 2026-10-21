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

    public init(app: String, version: String, build: String, macOS: String, model: String, crashes: [String]) {
        (self.app, self.version, self.build, self.macOS, self.model, self.crashes) = (app, version, build, macOS, model, crashes)
    }

    /// The report for `app`: the newest three of `crashes` from suite processes at most 7 days before `now`, each
    /// trimmed to its header and crashed thread, with `home`, `user` and `host` redacted. Stub: no crashes (RP-4).
    public static func build(app: SuiteApp, version: String, build: String, macOS: String, model: String,
                             crashes: [CrashFile], now: Date, home: String, user: String, host: String) -> ProblemReport {
        ProblemReport(app: app.displayName, version: version, build: build, macOS: macOS, model: model, crashes: [])
    }

    /// The note, then the report, as plain text. Stub: the note alone (RP-4).
    public func text(note: String) -> String { note }
}
