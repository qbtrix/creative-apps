// SuitePlaybackDriverTests.swift: the suite's display-link driver (#5077) on a link the test fires by hand, so no test
// starts a real display link (the headless runner can't serve one). Start is once and stop is safe; no screen leaves
// it stopped; ticks hand the driver's ticker on and a false tick stops and invalidates the link; a restart counts no
// paused time; `measuredFPS` reads 24 for a second of 24 Hz ticks, 12 with every other one dropped, nil before a
// second has passed or after a stop. macOS only.
#if canImport(AppKit)
import SuiteKernel
@testable import SuiteUI
import Testing

/// A link the test fires by hand; after `invalidate()` it fires nothing.
@MainActor
final class HandFiredLink: RefreshLink {
    private let receive: @MainActor (Double) -> Void
    private(set) var invalidated = false

    init(_ receive: @escaping @MainActor (Double) -> Void) { self.receive = receive }

    func invalidate() { invalidated = true }

    func fire(_ target: Double) { if !invalidated { receive(target) } }
}

/// A driver whose ticks record each elapsed time and keep running while `running` says so.
@MainActor
private final class Rig {
    var links: [HandFiredLink] = []
    var elapsed: [Double?] = []
    var running = true
    lazy var driver = PlaybackDriver(
        onTick: { [weak self] target, ticker in
            self?.elapsed.append(ticker.elapsed(toTarget: target))
            return self?.running ?? false
        },
        makeLink: { [weak self] receive in
            let link = HandFiredLink(receive)
            self?.links.append(link)
            return link
        })
}

@MainActor
@Suite(.timeLimit(.minutes(10))) struct SuitePlaybackDriverTests {
    @Test func startIsOnceAndStopIsSafe() {
        let rig = Rig()
        rig.driver.stop()
        rig.driver.start()
        rig.driver.start()
        #expect(rig.driver.isRunning && rig.links.count == 1)
        rig.driver.stop()
        #expect(!rig.driver.isRunning && rig.links[0].invalidated)
        rig.driver.start()
        #expect(rig.links.count == 2)
    }

    @Test func nothingToRefreshOnLeavesTheDriverStopped() {
        let driver = PlaybackDriver(onTick: { _, _ in true }, makeLink: { _ in nil })
        driver.start()
        #expect(!driver.isRunning)
    }

    @Test func ticksPassTheTargetsAndAFalseTickStopsTheLink() throws {
        let rig = Rig()
        rig.driver.start()
        let link = try #require(rig.links.last)
        link.fire(7000)
        link.fire(7000.5)
        #expect(rig.elapsed == [nil, 0.5] && rig.driver.lastTarget == 7000.5)
        rig.running = false
        link.fire(7001)
        #expect(!rig.driver.isRunning && link.invalidated)
        link.fire(7002)
        #expect(rig.elapsed.count == 3)
    }

    /// A stop forgets the baseline: the first tick after a restart only sets it, so the pause never counts.
    @Test func aRestartCountsNoPausedTime() throws {
        let rig = Rig()
        rig.driver.start()
        try #require(rig.links.last).fire(7000)
        rig.driver.stop()
        rig.driver.start()
        let link = try #require(rig.links.last)
        link.fire(7010)
        link.fire(7010.25)
        #expect(rig.elapsed == [nil, nil, 0.25])
    }

    /// One second of ticks at 24 Hz from the link's media clock; `keep` picks which arrive.
    private func measure(_ keep: (Int) -> Bool) -> PlaybackDriver {
        let driver = PlaybackDriver(onTick: { _, _ in true }, makeLink: { _ in nil })
        for tick in 0...24 where keep(tick) { driver.receive(target: 7000 + Double(tick) / 24) }
        return driver
    }

    @Test func aSecondOfTicksAtTwentyFourMeasuresTwentyFour() {
        #expect(measure { _ in true }.measuredFPS == 24)
        #expect(measure { $0 % 2 == 0 }.measuredFPS == 12)
    }

    @Test func noMeasureBeforeASecondOrAfterAStop() {
        #expect(measure { $0 < 12 }.measuredFPS == nil)
        let driver = measure { _ in true }
        driver.stop()
        #expect(driver.measuredFPS == nil)
        let late = measure { _ in true }
        late.receive(target: .nan)
        late.receive(target: 6999)
        #expect(late.measuredFPS == 24)
    }
}
#endif
