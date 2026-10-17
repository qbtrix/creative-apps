// SizeGate.swift: UC-17 size budget (docs/blueprints/suite.md 5.6 and 7.5).
// Pure: every entry over its limit is a finding, then every app whose
// SuiteUI symbol count is over the maximum, in app-name order. A finding is
// hard unless its name is in the budget's report-only set.

/// Judges a size report against a budget.
public protocol SizeBudgetChecking: Sendable {
    func evaluate(_ report: SizeReport, against budget: SizeBudget) -> [SizeFinding]
}

/// The live size gate.
public struct SizeGate: SizeBudgetChecking {
    public init() {}

    public func evaluate(_ report: SizeReport, against budget: SizeBudget) -> [SizeFinding] {
        var out: [SizeFinding] = []
        for entry in report.entries {
            guard let limit = budget.limits[entry.name], entry.bytes > limit else { continue }
            out.append(SizeFinding(
                name: entry.name, measured: entry.bytes, limit: limit,
                hard: !budget.reportOnly.contains(entry.name)
            ))
        }
        for (app, count) in report.suiteUISymbols.sorted(by: { $0.key < $1.key })
        where count > budget.maxSuiteUISymbols {
            let name = "\(app) SuiteUI symbols"
            out.append(SizeFinding(
                name: name, measured: count, limit: budget.maxSuiteUISymbols,
                hard: !budget.reportOnly.contains(name)
            ))
        }
        return out
    }
}
