// CrashFolder.swift (report-problem RP-5b): which folder Report a Problem reads crashes from, and which of its
// files it opens. `~/Library/Logs/DiagnosticReports` unless the launch arguments name another with
// `-SuiteCrashDir <path>` (the Help journey's fixture folder). Only crash files (`.ips` and the older `.crash`)
// whose name starts with a suite process and that are at most 7 days old are opened, newest first and at most
// `limit`. The suite filter comes before the cap, so a Mac busy with other apps' crashes can't push the suite's
// out; ProblemReport then keeps the newest three. Pure values: CrashFolderReader does the reading.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// The crash folder and the files in it worth reading.
public enum CrashFolder {
    /// The flag a journey passes to point the report at a fixture folder.
    public static let flag = "-SuiteCrashDir"
    /// The most files opened for one report.
    public static let limit = 50
    /// The oldest crash a report shows, in seconds: ProblemReport's 7 days.
    static let maxAge: Double = 7 * 86_400
    /// The crash file kinds: today's `.ips` and the older plain-text `.crash`.
    static let extensions = [".ips", ".crash"]

    /// One file in the folder: its name and when it was last written.
    public struct Entry: Hashable, Sendable {
        public var name: String
        public var modified: Date
        public init(name: String, modified: Date) { (self.name, self.modified) = (name, modified) }
    }

    /// The path after `-SuiteCrashDir` when the arguments carry a non-empty one, else `home`'s DiagnosticReports.
    public static func path(arguments: [String], home: String) -> String {
        if let at = arguments.firstIndex(of: flag) {
            let next = arguments.index(after: at)
            if next < arguments.endIndex, !arguments[next].isEmpty { return arguments[next] }
        }
        let base = home.hasSuffix("/") ? String(home.dropLast()) : home
        return base + "/Library/Logs/DiagnosticReports"
    }

    /// Whether `name` is a crash file: `.ips` or `.crash`.
    public static func isCrash(_ name: String) -> Bool { extensions.contains { name.hasSuffix($0) } }

    /// The process a crash file's name starts with: the part before its first "-" (`Photo-2026-10-21-….ips`) or
    /// "_" (`Photo_2026-10-21-…_Mac.crash`).
    static func process(named name: String) -> String { String(name.prefix { $0 != "-" && $0 != "_" }) }

    /// The suite's crash entries at most 7 days before `now`, newest first, at most `limit`.
    public static func toRead(_ entries: [Entry], now: Date) -> [Entry] {
        let suite = Set(SuiteApp.allCases.map(\.displayName))
        return Array(entries
            .filter { isCrash($0.name) && suite.contains(process(named: $0.name)) }
            .filter { now.timeIntervalSince($0.modified) <= maxAge }
            .sorted { $0.modified > $1.modified }
            .prefix(limit))
    }
}
