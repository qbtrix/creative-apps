// CrashFolder.swift (report-problem RP-5b): which folder Report a Problem reads crashes from, and which of its
// files it opens. `~/Library/Logs/DiagnosticReports` unless the launch arguments name another with
// `-SuiteCrashDir <path>` (the Help journey's fixture folder). Only `.ips` files at most 7 days old are opened,
// newest first and at most `limit`, so a Mac full of old crash logs costs nothing; ProblemReport then keeps the
// suite's newest three. Pure values, like SuiteLocations: SuiteShell's CrashFolderReader does the reading.
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

    /// The `.ips` entries at most 7 days before `now`, newest first, at most `limit`.
    public static func toRead(_ entries: [Entry], now: Date) -> [Entry] {
        Array(entries
            .filter { $0.name.hasSuffix(".ips") && now.timeIntervalSince($0.modified) <= maxAge }
            .sorted { $0.modified > $1.modified }
            .prefix(limit))
    }
}
