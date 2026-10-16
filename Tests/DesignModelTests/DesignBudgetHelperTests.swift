// DesignBudgetHelperTests.swift: the budget helper (DesignBudget) itself. Its
// median and p95 are right on known samples, it runs the body exactly N times,
// and it fails a body that runs past its gate (a 1 ms gate and a 3 ms busy
// wait, so the suite stays fast). Runs on Linux and macOS.
import Testing

/// Spins on the clock for `duration`, so the run takes at least that long.
private func busyWait(_ duration: Duration) {
    let clock = ContinuousClock()
    let end = clock.now + duration
    while clock.now < end {}
}

@Suite struct DesignBudgetHelperTests {
    @Test func reportsMedianAndP95() {
        let odd = DesignBudget.Report(samples: [5, 1, 4, 2, 3].map { Duration.milliseconds($0) })
        #expect(odd.runs == 5)
        #expect(odd.median == .milliseconds(3))
        #expect(odd.p95 == .milliseconds(5))

        let even = DesignBudget.Report(samples: [4, 1, 3, 2].map { Duration.milliseconds($0) })
        #expect(even.median == .microseconds(2_500))

        // 100 runs of 1...100 ms: the 95th smallest is the p95.
        let hundred = DesignBudget.Report(samples: (1...100).reversed().map { Duration.milliseconds($0) })
        #expect(hundred.p95 == .milliseconds(95))
        #expect(hundred.median == .microseconds(50_500))

        let twenty = DesignBudget.Report(samples: (1...20).map { Duration.milliseconds($0) })
        #expect(twenty.p95 == .milliseconds(19))

        #expect(DesignBudget.Report(samples: []) == DesignBudget.Report(samples: []))
        #expect(DesignBudget.Report(samples: []).p95 == .zero)
    }

    @Test func gateIsInclusive() {
        let report = DesignBudget.Report(samples: [.milliseconds(2)])
        #expect(report.fits(.milliseconds(2)))
        #expect(!report.fits(.microseconds(1_999)))
        #expect(DesignBudget.linuxDebugGate(device: .milliseconds(1)) == .milliseconds(10))
    }

    @Test func runsTheBodyNTimes() {
        var count = 0
        let report = DesignBudget.measure(runs: 7) { count += 1 }
        #expect(count == 7)
        #expect(report.runs == 7)
        #expect(DesignBudget.measure(runs: 0) {}.runs == 1)
    }

    @Test func passesABodyUnderItsGate() {
        let report = DesignBudget.expect("nothing", runs: 5, gate: .seconds(1)) {}
        #expect(report.fits(.seconds(1)))
    }

    @Test func failsABodyPastItsGate() {
        withKnownIssue {
            let report = DesignBudget.expect("slow", runs: 3, gate: .milliseconds(1)) {
                busyWait(.milliseconds(3))
            }
            #expect(report.median >= .milliseconds(3))
            #expect(report.p95 >= .milliseconds(3))
        }
    }
}
