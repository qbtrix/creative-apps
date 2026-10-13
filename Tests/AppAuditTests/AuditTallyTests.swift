// AuditTallyTests.swift: the app audit's ratchet. A violation counts once
// per app however many screens show it; a new one past the baseline fails
// and names its check and fault; a count that fell doesn't fail, and the
// counts list every baseline check for scripts/audit-lower; an unlisted app
// is not judged. Runs on Linux and macOS (docs/blueprints/app-audit.md).
import Testing

private func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> AppAudit.Rect {
    AppAudit.Rect(x: x, y: y, width: w, height: h)
}

/// A report with one `check` violation per element name, each at its own x.
private func report(_ screen: String, _ check: String, _ names: [String]) -> AppAudit.Report {
    let violations = names.enumerated().map { i, name in
        AppAudit.Violation(check: check, element: "button '\(name)'", frame: rect(Double(i * 50), 0, 40, 20), detail: "d")
    }
    return AppAudit.Report(
        screen: screen, app: "photo", scale: 1, display: rect(0, 0, 1, 1), window: rect(0, 0, 1, 1), modal: false,
        counts: [check: names.count], violations: violations, samples: [])
}

@Test func namedElementCountsOnceWhereverItMoves() {
    func moved(_ x: Double) -> AppAudit.Report {
        let v = AppAudit.Violation(check: "identifier", element: "slider 'White'", frame: rect(x, 0, 40, 20), detail: "d")
        let u = AppAudit.Violation(check: "identifier", element: "staticText ''", frame: rect(x, 0, 40, 20), detail: "d")
        return AppAudit.Report(
            screen: "s", app: "photo", scale: 1, display: rect(0, 0, 1, 1), window: rect(0, 0, 1, 1), modal: false,
            counts: ["identifier": 2], violations: [v, u], samples: [])
    }
    var tally = AppAudit.Tally(app: "photo", baseline: nil)
    _ = tally.add(moved(0))
    _ = tally.add(moved(100))
    #expect(tally.seen["identifier"]?.count == 3)
}

@Test func tallyCountsAViolationOnceAcrossScreens() {
    var tally = AppAudit.Tally(app: "photo", baseline: ["identifier": 2])
    #expect(tally.add(report("photo-a", "identifier", ["Undo", "Redo"])).isEmpty)
    #expect(tally.add(report("photo-b", "identifier", ["Undo", "Redo"])).isEmpty)
    #expect(tally.seen["identifier"]?.count == 2)
    #expect(tally.counts == ["identifier": 2])
}

@Test func tallyFailsANewViolationPastTheBaselineAndNamesItsFault() throws {
    var tally = AppAudit.Tally(app: "photo", baseline: ["identifier": 1])
    let failures = tally.add(report("photo-a", "identifier", ["Undo", "Redo"]))
    let failure = try #require(failures.first)
    #expect(failures.count == 1)
    #expect(failure.hasPrefix("photo identifier (fault #262"))
    #expect(failure.contains("2 violations, baseline 1. New on photo-a: button 'Redo' at [50,0,40,20], d."))
}

@Test func countThatDroppedDoesNotFailAndEveryBaselineCheckIsCounted() {
    var tally = AppAudit.Tally(app: "photo", baseline: ["identifier": 3, "overlap": 1])
    #expect(tally.add(report("photo-a", "identifier", ["Undo"])).isEmpty)
    #expect(tally.counts == ["identifier": 1, "overlap": 0])
}

@Test func tallyJudgesNothingForAnUnlistedApp() {
    var tally = AppAudit.Tally(app: "photo", baseline: nil)
    #expect(tally.add(report("photo-a", "identifier", ["Undo"])).isEmpty)
    #expect(tally.counts == ["identifier": 1])
}

@Test func checkMissingFromTheBaselineHasBaselineZero() {
    var tally = AppAudit.Tally(app: "photo", baseline: [:])
    #expect(tally.add(report("photo-a", "unnamed", ["x"])).count == 1)
}
