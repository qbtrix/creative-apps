// BodyCountSuites.swift: the one parent for every suite that reads a view's
// DEBUG body counter (HaloWindow.bodyRuns, TimelineLane.bodyRuns,
// PhotoEditor.bodyRuns, ...). Its trait gives each test case its own
// BodyTallyScope (SuiteUI's BodyTally.swift): every harness window the test
// opens reports to it, and `bodyRuns` reads only that, so suites running
// alongside in the same process never move the count (factory lesson 345;
// before, one run saw 49 window bodies where 24 is right).
// `.serialized` still runs these suites one at a time, so their timings and
// settles don't compete. Nested suites join with `extension BodyCountSuites`,
// and scripts/check-body-counts fails a `bodyRuns` read outside it.
//
// `settle(untilStable:)` is the settle a counter-reading test runs before it
// measures: a fixed sleep after opening a big file is too short on a slow
// runner, and the window's first layouts after the open then land inside the
// measured interaction (#1974: a 120-sample drag counted 6 or 7 window bodies
// where 3 is right).
import SuiteUI
import Testing

@Suite(.serialized, .bodyTallyScope) enum BodyCountSuites {}

/// A fresh BodyTallyScope around each test case under the suite it is on, and the suites nested in it. A
/// recursive suite trait is applied to every test function too, so it is a TestTrait as well.
struct BodyTallyScopeTrait: SuiteTrait, TestTrait, TestScoping {
    var isRecursive: Bool { true }

    func scopeProvider(for test: Test, testCase: Test.Case?) -> Self? { testCase == nil ? nil : self }

    func provideScope(
        for test: Test, testCase: Test.Case?, performing function: @Sendable () async throws -> Void
    ) async throws {
        try await BodyTallyTest.$scope.withValue(BodyTallyScope()) { try await function() }
    }
}

extension Trait where Self == BodyTallyScopeTrait {
    /// Each test case's own count for `bodyRuns`: the windows it opens (BodyTally.swift).
    static var bodyTallyScope: Self { Self() }
}

#if canImport(AppKit)
import AppKit

extension RenderBudgetWindow {
    /// Forces layout and display and turns the run loop until `bodies` reads the same for `turns` checks
    /// in a row, `interval` ms apart, so the work left from opening the window (first layouts, the fit, an
    /// async load) is done before a measurement starts. Records an issue when it is still changing after
    /// `limit` ms. In release `bodies` is nil, so this is a plain settle of `turns` checks.
    func settle(
        untilStable bodies: () -> Int?, turns: Int = 6, interval: Int = 50, limit: Int = 10_000,
        sourceLocation: SourceLocation = #_sourceLocation
    ) async throws {
        var last = bodies()
        var stable = 0
        var waited = 0
        while waited < limit {
            host.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            try await settle(interval)
            waited += interval
            let now = bodies()
            if now == last {
                stable += 1
                if stable >= turns { return }
            } else {
                stable = 0
                last = now
            }
        }
        Issue.record("the window's bodies were still running after \(limit) ms", sourceLocation: sourceLocation)
    }
}
#endif
