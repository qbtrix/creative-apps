// SizeReport.swift: the size report `scripts/size-report` writes and the
// budget it is judged against (docs/blueprints/suite.md 5.6, the bundle
// packet's contract slice). Not a runtime service: `SizeGateTests` evaluates
// a report against the budget. Linux-safe, Sendable.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// What a size row measures.
public enum SizeEntryKind: String, Codable, Sendable {
    case executable, framework, appBundle, wholeBundle, tarball
}

/// One measured row: "Flare", "SuiteUI.framework", "AfterGlow.app".
public struct SizeEntry: Codable, Equatable, Sendable {
    public var name: String
    public var kind: SizeEntryKind
    public var bytes: Int

    public init(name: String, kind: SizeEntryKind, bytes: Int) {
        self.name = name
        self.kind = kind
        self.bytes = bytes
    }
}

/// One build's sizes, plus the SuiteUI symbols defined in each app
/// executable (app name -> count; 0 once SuiteUI is a framework).
public struct SizeReport: Codable, Equatable, Sendable {
    public var commit: String
    public var entries: [SizeEntry]
    public var suiteUISymbols: [String: Int]

    public init(commit: String, entries: [SizeEntry], suiteUISymbols: [String: Int]) {
        self.commit = commit
        self.entries = entries
        self.suiteUISymbols = suiteUISymbols
    }
}

/// The limits a report is judged against. A name in `reportOnly` (an entry
/// name, or "<app> SuiteUI symbols") is reported but never hard.
public struct SizeBudget: Codable, Equatable, Sendable {
    /// Entry name -> bytes.
    public var limits: [String: Int]
    public var maxSuiteUISymbols: Int
    public var reportOnly: Set<String>

    public init(limits: [String: Int], maxSuiteUISymbols: Int = 0, reportOnly: Set<String> = []) {
        self.limits = limits
        self.maxSuiteUISymbols = maxSuiteUISymbols
        self.reportOnly = reportOnly
    }
}

/// A row over its limit. `hard` findings fail the gate; soft ones only report.
public struct SizeFinding: Equatable, Sendable {
    public var name: String
    public var measured: Int
    public var limit: Int
    public var hard: Bool

    public init(name: String, measured: Int, limit: Int, hard: Bool) {
        self.name = name
        self.measured = measured
        self.limit = limit
        self.hard = hard
    }
}
