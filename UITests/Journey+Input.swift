// Journey+Input.swift: the input and probe helpers every journey bundle
// compiles next to Journey.swift. Keys with modifiers, a velocity-controlled
// drag (300 a second by default, so a perf journey draws enough frames), and
// the readers of the two hidden elements a window publishes under
// `-SuitePerfProbe`: `suite.perf` (`perf()`, a ProbeDocument) and
// `suite.controls` (`controls()`, a ControlDocument). Both are the JSON label
// of their element, decoded with the same contract types the app encodes
// (project.yml compiles Sources/SuiteUI/Contracts' three Foundation-only
// files into every bundle). Perf numbers are report-only until their gates
// land: `perf()` attaches the document as "perf-<test>" and `expectValid`
// fails a series under 60 samples, which says nothing about its timing.
// A journey class that conforms to `PerfBudgeted` (SuiteJourneyTests, in
// SuiteJourneyTests+Budgets.swift) names its gates; `perf()` reads them and
// attaches each measured series against its gate as "perf-budgets-<test>",
// failing only a gate marked `enforced`.
import XCTest

/// One perf gate (blueprint suiteui 7.1): the p95 a row's series may reach,
/// in frames late (`latency`) or in refreshes between drawn frames
/// (`intervals`). `limit` nil means the gate is set from CI later; a miss
/// fails only once `enforced` (after ten green runs, a one-line PR).
struct PerfBudget: Sendable {
    enum Measure: String, Sendable { case latency, intervals, fade }
    let row: String
    let series: [String]
    let measure: Measure
    let limit: Double?
    var enforced = false
}

/// A journey class whose perf series have gates; `perf()` reads them.
protocol PerfBudgeted {
    static var perfBudgets: [PerfBudget] { get }
}

extension Journey {
    /// Fewer samples than this and a series' summary is not valid (blueprint section 7).
    static let minimumSamples = 60

    /// Presses `key` with `modifiers`; shoots `step` when given one.
    func press(_ key: XCUIKeyboardKey, _ modifiers: XCUIElement.KeyModifierFlags = [], step: String? = nil) {
        app.typeKey(key, modifierFlags: modifiers)
        if let step { shot(step) }
    }

    /// Presses the key that types `character` with `modifiers` (⌘= is
    /// `press(character: "=", .command)`); shoots `step` when given one.
    func press(character: String, _ modifiers: XCUIElement.KeyModifierFlags = [], step: String? = nil) {
        app.typeKey(character, modifierFlags: modifiers)
        if let step { shot(step) }
    }

    /// Drags across the element `identifier` from `start` through each of
    /// `through` to `end`, points given as fractions of its size, at
    /// `velocity` (XCUIGestureVelocity: pixels a second). Each leg is its own
    /// click, drag and release; shoots `step` once at the end when given one.
    func velocityDrag(
        on identifier: String, from start: CGVector, through: [CGVector] = [], to end: CGVector,
        velocity: XCUIGestureVelocity = 300, step: String? = nil
    ) {
        let target = element(identifier)
        XCTAssert(target.waitForExistence(timeout: 10), "no \(identifier) to drag on")
        let stops = [start] + through + [end]
        for (from, to) in zip(stops, stops.dropFirst()) {
            target.coordinate(withNormalizedOffset: from).click(
                forDuration: 0.05, thenDragTo: target.coordinate(withNormalizedOffset: to),
                withVelocity: velocity, thenHoldForDuration: 0.05)
        }
        if let step { shot(step) }
    }

    /// The window's `suite.perf` document, attached as "perf-<test>"; nil
    /// (and a failure) when the app wasn't launched with `-SuitePerfProbe`.
    @discardableResult
    func perf() -> ProbeDocument? {
        guard let document = decodeLabel(of: "suite.perf", as: ProbeDocument.self) else { return nil }
        attachJSON(document, as: "perf-\(slug(test.name))")
        if let budgeted = test as? any PerfBudgeted { checkBudgets(type(of: budgeted).perfBudgets, in: document) }
        return document
    }

    /// Attaches every measured series against its gate as
    /// "perf-budgets-<test>" (`series: p95 / limit`); fails an enforced miss.
    private func checkBudgets(_ budgets: [PerfBudget], in document: ProbeDocument) {
        var report: [String: String] = [:]
        for budget in budgets {
            for series in budget.series {
                let p95: Double? = switch budget.measure {
                case .latency: document.latency[series].map { Double($0.p95FramesLate) }
                case .intervals: document.intervals[series]?.p95Refreshes
                case .fade: nil
                }
                guard let p95 else { continue }
                let limit = budget.limit.map { "\($0)" } ?? "unset"
                let mode = budget.enforced ? "gate" : "report-only"
                report["\(budget.row) \(series)"] = "p95 \(p95) / \(limit) (\(mode))"
                if budget.enforced, let gate = budget.limit {
                    XCTAssertLessThanOrEqual(p95, gate, "\(budget.row) \(series): p95 \(p95) over its gate \(gate)")
                }
            }
        }
        if !report.isEmpty { attachJSON(report, as: "perf-budgets-\(slug(test.name))") }
    }

    /// Fails when `series` has fewer than `minimumSamples` samples in `document`.
    func expectValid(_ document: ProbeDocument, series: String) {
        let count = document.latency[series]?.count ?? 0
        XCTAssert(
            count >= Self.minimumSamples,
            "series \(series) has \(count) samples, under \(Self.minimumSamples): its numbers mean nothing")
    }

    /// The window's `suite.controls` document; nil (and a failure) when the
    /// app wasn't launched with `-SuitePerfProbe`.
    func controls() -> ControlDocument? {
        decodeLabel(of: "suite.controls", as: ControlDocument.self)
    }

    private func decodeLabel<T: Decodable>(of identifier: String, as type: T.Type) -> T? {
        let probe = element(identifier)
        guard probe.waitForExistence(timeout: 5) else {
            XCTFail("no \(identifier): launch with -SuitePerfProbe")
            return nil
        }
        do {
            return try JSONDecoder().decode(type, from: Data(probe.label.utf8))
        } catch {
            XCTFail("\(identifier) isn't a \(T.self): \(error)")
            return nil
        }
    }

    private func attachJSON(_ value: some Encodable, as attachmentName: String) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let json = try? encoder.encode(value) else { return }
        let attachment = XCTAttachment(data: json, uniformTypeIdentifier: "public.json")
        attachment.name = attachmentName
        attachment.lifetime = .keepAlways
        test.add(attachment)
    }
}
