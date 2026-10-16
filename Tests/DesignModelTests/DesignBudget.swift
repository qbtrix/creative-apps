// DesignBudget.swift: the timing helper the Model budget tests share
// (docs/blueprints/design.md section 7.1). It runs a body N times, reports the
// median and p95 of the runs, and records a test issue when the p95 is over the
// gate: the Linux debug gate, 10 × the device target unless a row says
// otherwise. design-seams' DesignBudgetTests and each wave-1 feature's
// Design<Area>BudgetTests call `DesignBudget.expect`. Runs on Linux and macOS.
import Testing

enum DesignBudget {
    /// The median and p95 of a set of timed runs.
    struct Report: Equatable, CustomStringConvertible {
        let runs: Int
        let median: Duration
        let p95: Duration

        /// From the run times in any order. The median of an even count is the mean of the middle
        /// two; the p95 is the nearest-rank value (the smallest run at or above 95% of them).
        /// No samples report zero.
        init(samples: [Duration]) {
            let sorted = samples.sorted()
            runs = sorted.count
            guard !sorted.isEmpty else {
                (median, p95) = (.zero, .zero)
                return
            }
            let middle = sorted.count / 2
            median = sorted.count % 2 == 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2
            let rank = (sorted.count * 95 + 99) / 100  // ceil(0.95 n), 1-based
            p95 = sorted[Swift.min(Swift.max(rank, 1), sorted.count) - 1]
        }

        /// Whether the p95 is at or under `gate`.
        func fits(_ gate: Duration) -> Bool { p95 <= gate }

        var description: String { "median \(median), p95 \(p95) over \(runs) runs" }
    }

    /// The Linux debug gate for a device target: 10 × the target (section 7.1).
    static func linuxDebugGate(device: Duration) -> Duration { device * 10 }

    /// Times `body` `runs` times (at least once) on the continuous clock.
    static func measure(runs: Int, _ body: () throws -> Void) rethrows -> Report {
        let clock = ContinuousClock()
        var samples: [Duration] = []
        samples.reserveCapacity(Swift.max(runs, 1))
        for _ in 0..<Swift.max(runs, 1) {
            samples.append(try clock.measure(body))
        }
        return Report(samples: samples)
    }

    /// Times `body` `runs` times and records an issue naming `name` when its p95 is over `gate`.
    @discardableResult
    static func expect(
        _ name: String, runs: Int = 200, gate: Duration,
        sourceLocation: SourceLocation = #_sourceLocation, _ body: () throws -> Void
    ) rethrows -> Report {
        let report = try measure(runs: runs, body)
        if !report.fits(gate) {
            Issue.record("\(name): \(report), over the gate \(gate)", sourceLocation: sourceLocation)
        }
        return report
    }
}
