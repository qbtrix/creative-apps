// BodyTally.swift: the one per-window count of view body runs, for budget
// tests. A test puts a BodyTally in its window's environment
// (`.environment(\.bodyTally, tally)`); every view that reports, in debug
// builds, adds one run under its own type each time its body runs
// (`bodyTally?.ran(Self.self)`), and the test reads `runs(of:)`. Each window
// has its own tally, so suites that draw other windows in the same process
// never move its counts (factory lesson 345: never assert on a process-wide
// static). Outside a test the environment holds nil and reporting is a no-op.
// It is a plain class, not an observable one: a body that bumped an observed
// count would invalidate itself.
import SwiftUI

/// One window's body runs, by view type.
@MainActor public final class BodyTally {
    private var counts: [ObjectIdentifier: Int] = [:]

    public init() {}

    /// One more body run of `view`.
    public func ran<V: View>(_ view: V.Type) { counts[ObjectIdentifier(view), default: 0] += 1 }

    /// How many times `view`'s body ran in this window.
    public func runs<V: View>(of view: V.Type) -> Int { counts[ObjectIdentifier(view)] ?? 0 }
}

extension EnvironmentValues {
    /// The tally this window's views report their body runs to; nil outside a test that asks.
    public var bodyTally: BodyTally? {
        get { self[BodyTallyKey.self] }
        set { self[BodyTallyKey.self] = newValue }
    }
}

/// A plain key rather than `@Entry`, as SidebarExpansionKey.
private struct BodyTallyKey: EnvironmentKey {
    static let defaultValue: BodyTally? = nil
}
