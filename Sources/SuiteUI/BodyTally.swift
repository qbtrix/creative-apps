// BodyTally.swift: the one count of view body runs, by window and by test,
// for budget tests (factory lesson 345: never assert on a process-wide
// static). A counted view conforms to BodyCounted, reads `bodyTally` from its
// environment and reports each body run with `let _ = bodyTally.ran(Self.self)`.
// A tally passes every run on to its parent: a window's to its test's, a
// test's to `BodyTally.process`, the count over every window, which is also
// the environment's default, so outside a test a run counts only there.
// BodyCounted's `bodyRuns` is `BodyTally.runs(of:)`: the running test's count
// when the test task has a scope, else the process's.
//
// The scope is `BodyTallyTest.scope`, a task-local the test target binds once
// per test case (BodyCountSuites' trait). A harness that opens a window calls
// `BodyTally.forNewWindow()` and puts the tally it returns in the window's
// environment; unless opened with `underTest: false` (a neighbour), that
// window reports to the test's tally. So a test counts every window it
// opened and nothing else: it starts at 0 and only grows, a suite running
// alongside reports under its own task and never moves it, and none of the
// call sites that read `bodyRuns` changes. A window's own tally (the
// harness's `tally`) counts that window alone.
//
// A generic view counts every specialization as one view: it reports and
// reads under one key type (TimelineLane's `TimelineLaneBodies`) and declares
// its own `bodyRuns`. Plain classes, not observable ones: a body that bumped
// an observed count would invalidate itself.
import SwiftUI

/// Body runs by view type: one window's, one test's or the process's.
@MainActor public final class BodyTally {
    private var counts: [ObjectIdentifier: Int] = [:]
    /// The tally every run here also counts in: the process's, or the test's for a window it opened.
    private let parent: BodyTally?

    nonisolated public init(parent: BodyTally? = BodyTally.process) { self.parent = parent }

    /// Every window's body runs, test or not; the environment's default tally.
    nonisolated public static let process = BodyTally(parent: nil)

    /// One more body run of `view` (a view type, or the key type a generic view reports under) here and in
    /// every tally above this one.
    public func ran(_ view: Any.Type) {
        counts[ObjectIdentifier(view), default: 0] += 1
        parent?.ran(view)
    }

    /// How many times `view`'s body ran in this window.
    public func runs(of view: Any.Type) -> Int { counts[ObjectIdentifier(view)] ?? 0 }

    /// `view`'s body runs in the windows the running test opened, or in every window when the test task has
    /// no scope.
    public static func runs(of view: Any.Type) -> Int {
        (BodyTallyTest.scope?.tally ?? process).runs(of: view)
    }

    /// A tally for a window a test is opening, to put in its environment (`.environment(\.bodyTally, tally)`).
    /// Unless `underTest` is false (a neighbour), its runs count in the test's `bodyRuns` too.
    public static func forNewWindow(underTest: Bool = true) -> BodyTally {
        BodyTally(parent: underTest ? (BodyTallyTest.scope?.tally ?? process) : process)
    }
}

/// A view whose body runs a budget test counts (it reports them with `bodyTally.ran(Self.self)`).
public protocol BodyCounted: View {}

extension BodyCounted {
    /// How many times this view's body ran in the windows the running test opened, or in every window.
    public static var bodyRuns: Int { BodyTally.runs(of: Self.self) }
}

/// One test case's count: every window it opened under test. The test target binds a fresh one per test case.
public final class BodyTallyScope: Sendable {
    /// The tally `bodyRuns` reads while this scope is bound; 0 until the test's windows run a body.
    public let tally = BodyTally()

    public init() {}
}

/// Where the running test case's scope lives (a task-local, so a suite running alongside has its own).
public enum BodyTallyTest {
    /// The running test case's scope; nil outside a scoped test.
    @TaskLocal public static var scope: BodyTallyScope?
}

extension EnvironmentValues {
    /// The tally this window's views report their body runs to; the process's outside a test that asks.
    public var bodyTally: BodyTally {
        get { self[BodyTallyKey.self] }
        set { self[BodyTallyKey.self] = newValue }
    }
}

/// A plain key rather than `@Entry`, as SidebarExpansionKey.
private struct BodyTallyKey: EnvironmentKey {
    static let defaultValue = BodyTally.process
}
