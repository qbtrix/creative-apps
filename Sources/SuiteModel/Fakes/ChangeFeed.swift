// ChangeFeed.swift: holds the continuations of an actor's `changes()`
// streams and yields a revision to each. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// Holds the continuations of `changes()` streams for an actor.
struct ChangeFeed {
    private var continuations: [AsyncStream<Int>.Continuation] = []
    mutating func stream() -> AsyncStream<Int> {
        let (s, c) = AsyncStream<Int>.makeStream()
        continuations.append(c)
        return s
    }
    func send(_ revision: Int) { for c in continuations { c.yield(revision) } }
}
