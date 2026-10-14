// Packaging.swift: the size report and its budget (SuiteModel, planned
// `Sources/SuiteModel/Packaging/`, owned by the bundle feature). Not a
// runtime service, so not in SuiteServices: `scripts/size-report` writes a
// SizeReport and `SizeGateTests` evaluates it against the committed budget.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

public enum SizeEntryKind: String, Codable, Sendable { case executable, framework, appBundle, wholeBundle, tarball }

public struct SizeEntry: Codable, Equatable, Sendable {
    public var name: String                  // "Flare", "SuiteUI.framework", "AfterGlow.app"
    public var kind: SizeEntryKind
    public var bytes: Int
    public init(name: String, kind: SizeEntryKind, bytes: Int) { self.name = name; self.kind = kind; self.bytes = bytes }
}

public struct SizeReport: Codable, Equatable, Sendable {
    public var commit: String
    public var entries: [SizeEntry]
    public var suiteUISymbols: [String: Int]  // per app executable; 0 once SuiteUI is a framework
    public init(commit: String, entries: [SizeEntry], suiteUISymbols: [String: Int]) {
        self.commit = commit; self.entries = entries; self.suiteUISymbols = suiteUISymbols
    }
}

public struct SizeBudget: Codable, Equatable, Sendable {
    public var limits: [String: Int]          // entry name -> bytes
    public var maxSuiteUISymbols: Int
    public init(limits: [String: Int], maxSuiteUISymbols: Int = 0) { self.limits = limits; self.maxSuiteUISymbols = maxSuiteUISymbols }
}

public struct SizeFinding: Equatable, Sendable {
    public var name: String
    public var measured: Int
    public var limit: Int
    public init(name: String, measured: Int, limit: Int) { self.name = name; self.measured = measured; self.limit = limit }
}

/// UC-17 Size budget (tier 3, gates packaging). Pure; `scripts/size-report` feeds it.
public protocol SizeBudgetChecking: Sendable {
    func evaluate(_ report: SizeReport, against budget: SizeBudget) -> [SizeFinding]
}

public struct FakeSizeBudget: SizeBudgetChecking {
    public init() {}
    public func evaluate(_ report: SizeReport, against budget: SizeBudget) -> [SizeFinding] {
        var out = report.entries.compactMap { e -> SizeFinding? in
            guard let limit = budget.limits[e.name], e.bytes > limit else { return nil }
            return SizeFinding(name: e.name, measured: e.bytes, limit: limit)
        }
        for (app, n) in report.suiteUISymbols.sorted(by: { $0.key < $1.key }) where n > budget.maxSuiteUISymbols {
            out.append(SizeFinding(name: "\(app) SuiteUI symbols", measured: n, limit: budget.maxSuiteUISymbols))
        }
        return out
    }
}
