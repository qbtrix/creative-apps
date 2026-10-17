// SizeGateTests.swift: the size gate judges a size report against the
// provisional budget of docs/blueprints/suite.md 7.5. A hard row over its
// limit fails, a report-only row only reports, and SuiteUI symbols in an app
// executable are a finding. With SUITE_SIZE_REPORT set to a report's path,
// that report must have no hard finding.
import Foundation
import SuiteModel
import Testing

@Suite struct SizeGateTests {
    static let mb = 1_048_576

    /// 7.5's provisional numbers. App executables are report-only until BU-6
    /// sets their measured limits; the symbol count is report-only for one run.
    static let budget75 = SizeBudget(
        limits: [
            "SuiteUI.framework": 4 * mb,
            "CreativeEngines.framework": 6 * mb,
            "AfterGlow": 2 * mb,
            "app-builds.tar.gz": 15 * mb,
        ],
        maxSuiteUISymbols: 0,
        reportOnly: []
    )

    static let overJSON = """
    {
      "commit": "0123abc",
      "entries": [
        {"name": "AfterGlow", "kind": "executable", "bytes": 1000000},
        {"name": "SuiteUI.framework", "kind": "framework", "bytes": 3000000},
        {"name": "CreativeEngines.framework", "kind": "framework", "bytes": 7000000},
        {"name": "AfterGlow.app", "kind": "wholeBundle", "bytes": 20000000},
        {"name": "app-builds.tar.gz", "kind": "tarball", "bytes": 9000000}
      ],
      "suiteUISymbols": {"Flare": 0, "Design": 0}
    }
    """

    static func decode(_ json: String) throws -> SizeReport {
        try JSONDecoder().decode(SizeReport.self, from: Data(json.utf8))
    }

    @Test func overBudgetEnginesIsOneHardFinding() throws {
        let report = try Self.decode(Self.overJSON)
        let findings = SizeGate().evaluate(report, against: Self.budget75)
        #expect(findings == [
            SizeFinding(name: "CreativeEngines.framework", measured: 7_000_000, limit: 6 * Self.mb, hard: true),
        ])
    }

    @Test func reportOnlyRowOverItsLimitIsSoft() {
        var budget = Self.budget75
        budget.limits["Flare"] = 2 * Self.mb
        budget.reportOnly = ["Flare"]
        let report = SizeReport(
            commit: "c",
            entries: [SizeEntry(name: "Flare", kind: .executable, bytes: 3 * Self.mb)],
            suiteUISymbols: [:]
        )
        let findings = SizeGate().evaluate(report, against: budget)
        #expect(findings == [SizeFinding(name: "Flare", measured: 3 * Self.mb, limit: 2 * Self.mb, hard: false)])
    }

    @Test func rowAtItsLimitOrWithoutOneIsNoFinding() {
        let report = SizeReport(
            commit: "c",
            entries: [
                SizeEntry(name: "SuiteUI.framework", kind: .framework, bytes: 4 * Self.mb),
                SizeEntry(name: "Unbudgeted", kind: .appBundle, bytes: 99 * Self.mb),
            ],
            suiteUISymbols: ["Flare": 0]
        )
        #expect(SizeGate().evaluate(report, against: Self.budget75).isEmpty)
    }

    @Test func oneSuiteUISymbolOverLimitZeroIsAFinding() {
        let report = SizeReport(commit: "c", entries: [], suiteUISymbols: ["Photo": 0, "Flare": 1, "Design": 2])
        #expect(SizeGate().evaluate(report, against: Self.budget75) == [
            SizeFinding(name: "Design SuiteUI symbols", measured: 2, limit: 0, hard: true),
            SizeFinding(name: "Flare SuiteUI symbols", measured: 1, limit: 0, hard: true),
        ])
        var soft = Self.budget75
        soft.reportOnly = ["Flare SuiteUI symbols"]
        let findings = SizeGate().evaluate(report, against: soft)
        #expect(findings.map(\.hard) == [true, false])
    }

    @Test func suiteUISymbolLimitOfOneAllowsOneAndFlagsTwo() {
        var budget = Self.budget75
        budget.maxSuiteUISymbols = 1
        let atLimit = SizeReport(commit: "c", entries: [], suiteUISymbols: ["Flare": 1])
        #expect(SizeGate().evaluate(atLimit, against: budget).isEmpty)
        let over = SizeReport(commit: "c", entries: [], suiteUISymbols: ["Flare": 2])
        #expect(SizeGate().evaluate(over, against: budget) == [
            SizeFinding(name: "Flare SuiteUI symbols", measured: 2, limit: 1, hard: true),
        ])
    }

    @Test func budgetRoundTripsThroughJSON() throws {
        let budget = SizeBudget(limits: ["SuiteUI.framework": 4], maxSuiteUISymbols: 1, reportOnly: ["Flare"])
        let data = try JSONEncoder().encode(budget)
        #expect(try JSONDecoder().decode(SizeBudget.self, from: data) == budget)
    }

    static let envReportPath = ProcessInfo.processInfo.environment["SUITE_SIZE_REPORT"]

    @Test(.enabled(if: envReportPath != nil, "SUITE_SIZE_REPORT is not set"))
    func reportFromEnvironment() throws {
        let path = try #require(Self.envReportPath)
        let data = try Data(contentsOf: URL(fileURLWithPath: path))
        let report = try JSONDecoder().decode(SizeReport.self, from: data)
        let hard = SizeGate().evaluate(report, against: Self.budget75).filter(\.hard)
        #expect(hard.isEmpty, "hard size findings: \(hard)")
    }
}
