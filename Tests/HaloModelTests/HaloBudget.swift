// HaloBudget.swift: the timing rule Halo's budget tests share (blueprint
// 7.1): the quietest p95 of three rounds of 100 runs, since scripts/ci runs
// suites in parallel, against a device budget in release and ten times it in
// debug (CI). Each round prints its p50 and p95.

/// A budget: `device` milliseconds in release, ten times that in debug.
func haloBudget(device milliseconds: Int) -> Duration {
    #if DEBUG
    .milliseconds(milliseconds * 10)
    #else
    .milliseconds(milliseconds)
    #endif
}

/// The quietest p95 of three rounds of 100 runs of `work`, named `name` in
/// the printed lines.
func haloP95(_ name: String, budget: Duration, _ work: () -> Void) -> Duration {
    let clock = ContinuousClock()
    var p95s: [Duration] = []
    for _ in 0..<3 {
        let costs = (0..<100).map { _ in clock.measure(work) }.sorted()
        p95s.append(costs[94])
        print("HaloBudget \(name) p50 \(costs[49]) p95 \(costs[94]) budget \(budget)")
    }
    return p95s.min() ?? budget * 2
}
