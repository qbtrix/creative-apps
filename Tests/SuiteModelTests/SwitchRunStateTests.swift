// SwitchRunStateTests.swift: the switch plan for each run state (blueprint
// 2.3, shell-apps), and what the fake does after a quit or a missing app.
import SuiteModel
import Testing

@Suite struct SwitchRunStateTests {
    @Test func runningWithWindowsActivates() {
        #expect(SwitchPlanner.action(for: .flare, state: .running(windows: 2)) == .activate)
    }

    @Test func runningWithNoWindowOpens() {
        #expect(SwitchPlanner.action(for: .flare, state: .running(windows: 0)) == .open)
    }

    @Test func notRunningOpens() {
        #expect(SwitchPlanner.action(for: .flare, state: .notRunning) == .open)
    }

    @Test func missingIsRefusedWithItsSentence() {
        #expect(SwitchPlanner.action(for: .halo, state: .missing) == .refuse(.appMissing(.halo)))
    }

    @Test func aMissingAppIsRefusedByTheFake() async {
        let switching = FakeSwitching(missing: [.halo])
        await #expect(throws: SuiteError.appMissing(.halo)) {
            try await switching.switchTo(.halo, reason: .menu)
        }
    }

    @Test func aQuitAppOpensOnTheNextSwitch() async throws {
        let switching = FakeSwitching(running: [.flare])
        await switching.terminate(.flare)
        #expect(await switching.runState(of: .flare) == .notRunning)
        let receipt = try await switching.switchTo(.flare, reason: .menu)
        #expect(receipt.wasRunning == false)
        #expect(await switching.runState(of: .flare) == .running(windows: 1))
    }
}
