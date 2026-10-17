// BodyCountSuites.swift: the one parent for every suite that reads a
// process-global DEBUG body-run counter (HaloWindow.bodyRuns,
// TimelineLane.bodyRuns, PhotoEditor.bodyRuns, ...). Those counters are static,
// so two such suites running at once count each other's renders (one run saw
// 49 window bodies where 24 is right). `.serialized` on a suite orders only its
// own tests and nested suites; separate `.serialized` suites still run in
// parallel with each other, so these suites nest here with `extension
// BodyCountSuites`, and a new counter-reading suite must do the same.
//
// `settle(untilStable:)` is the settle a counter-reading test runs before it
// measures: a fixed sleep after opening a big file is too short on a slow
// runner, and the window's first layouts after the open then land inside the
// measured interaction (#1974: a 120-sample drag counted 6 or 7 window bodies
// where 3 is right).
import Testing

@Suite(.serialized) enum BodyCountSuites {}

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
