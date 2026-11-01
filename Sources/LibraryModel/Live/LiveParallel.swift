// Live/LiveParallel.swift: run independent pieces of one render across the
// cores (the develop's tiles, the histogram's bands) and get their results
// back in index order. The error of the lowest index that threw is the one
// rethrown, so a parallel render fails the way its serial loop would.
import Dispatch
import Synchronization

enum LiveParallel {
    /// `work(0) ... work(count - 1)` across the cores, results in index order.
    static func run<T: Sendable>(_ count: Int, _ work: @Sendable (Int) throws -> T) throws -> [T] {
        let results = Mutex<[Int: Result<T, any Error>]>([:])
        DispatchQueue.concurrentPerform(iterations: count) { i in
            let result = Result { try work(i) }
            results.withLock { $0[i] = result }
        }
        return try results.withLock { done in try (0..<count).compactMap { try done[$0]?.get() } }
    }
}
