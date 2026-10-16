// Budget.swift: the timing rule the suite's budget tests share (blueprint
// 7.1, the shape of HaloBudget): a device budget in release and ten times it
// in debug (the gate), and the median of a set of measured costs.

/// A budget: `device` milliseconds in release, ten times that in debug.
/// Fractional budgets (QB-SM1's 0.2 ms) keep microsecond precision.
func suiteBudget(device milliseconds: Double) -> Duration {
    #if DEBUG
    .microseconds(Int((milliseconds * 10_000).rounded()))
    #else
    .microseconds(Int((milliseconds * 1_000).rounded()))
    #endif
}

/// The median of `costs`; zero when there are none.
func suiteMedian(_ costs: [Duration]) -> Duration {
    let sorted = costs.sorted()
    guard !sorted.isEmpty else { return .zero }
    return sorted[sorted.count / 2]
}

/// Each run of `work`'s cost, measured `runs` times; `name` names the printed line.
func suiteMeasure(_ name: String, runs: Int, budget: Duration, _ work: (Int) async throws -> Void) async rethrows -> [Duration] {
    let clock = ContinuousClock()
    var costs: [Duration] = []
    for i in 0..<runs {
        let start = clock.now
        try await work(i)
        costs.append(clock.now - start)
    }
    print("SuiteBudget \(name) p50 \(suiteMedian(costs)) max \(costs.max() ?? .zero) budget \(budget)")
    return costs
}
