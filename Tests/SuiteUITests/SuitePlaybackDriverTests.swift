// SuitePlaybackDriverTests.swift: the suite's one playback refresh (OD-10). Every test runs the driver on a link the
// test fires by hand: none starts a real display link, which the headless CI runner can't serve. Start attaches one
// link, a second start doesn't add one, and stop invalidates it; a tick that says playback stopped stops the link;
// each target reaches `onTick` and `lastTarget` in order; `measuredFPS` counts the last second of targets (24 at
// 24 Hz, 12 with every other one dropped, nil before a second or after a stop). macOS only.
#if canImport(AppKit)
import Testing

@testable import SuiteUI

/// A link the test fires by hand; after `invalidate()` it fires nothing.
@MainActor
private final class FakeLink: SuiteRefreshLink {
    private let receive: @MainActor (Double) -> Void
    private(set) var invalidated = false

    init(_ receive: @escaping @MainActor (Double) -> Void) { self.receive = receive }

    func invalidate() { invalidated = true }

    func fire(_ target: Double) {
        if !invalidated { receive(target) }
    }
}

/// A driver whose every link is a FakeLink kept in `links`, and whose ticks land in `ticks`.
@MainActor
private final class Rig {
    private(set) var links: [FakeLink] = []
    private(set) var ticks: [Double] = []
    /// What each tick answers: whether playback is still running.
    var keepsPlaying = true
    lazy var driver = SuitePlaybackDriver(
        onTick: { [weak self] target in
            self?.ticks.append(target)
            return self?.keepsPlaying ?? false
        },
        makeLink: { [weak self] receive in
            let link = FakeLink(receive)
            self?.links.append(link)
            return link
        })

    var link: FakeLink? { links.last }
}

// The limit bounds a real hang, not the work: these share the main actor with every @MainActor snapshot suite in
// the process, so on CI they can queue for minutes before running (as HaloPlaybackDriverTests do).
@MainActor
@Suite(.timeLimit(.minutes(10))) struct SuitePlaybackDriverTests {
    @Test func startAttachesOneLinkAndStopInvalidatesIt() throws {
        let rig = Rig()
        rig.driver.stop()
        #expect(!rig.driver.isRunning)
        rig.driver.start()
        rig.driver.start()
        #expect(rig.links.count == 1)
        #expect(rig.driver.isRunning)
        let link = try #require(rig.link)
        rig.driver.stop()
        #expect(!rig.driver.isRunning)
        #expect(link.invalidated)
        rig.driver.start()
        #expect(rig.links.count == 2)
        rig.driver.stop()
    }

    @Test func eachRefreshReachesTheTickInOrder() throws {
        let rig = Rig()
        rig.driver.start()
        let link = try #require(rig.link)
        #expect(rig.driver.lastTarget == nil)
        for target in [5000.0, 5000.5, 5001] { link.fire(target) }
        #expect(rig.ticks == [5000, 5000.5, 5001])
        #expect(rig.driver.lastTarget == 5001)
        rig.driver.stop()
    }

    @Test func aTickThatStopsPlaybackStopsTheLink() throws {
        let rig = Rig()
        rig.driver.start()
        let link = try #require(rig.link)
        link.fire(5000)
        #expect(rig.driver.isRunning)
        rig.keepsPlaying = false
        link.fire(5001)
        #expect(!rig.driver.isRunning)
        #expect(link.invalidated)
        link.fire(5002)
        #expect(rig.ticks == [5000, 5001])
    }

    @Test func nothingToRefreshOnLeavesTheDriverStopped() {
        let driver = SuitePlaybackDriver(onTick: { _ in true }, makeLink: { _ in nil })
        driver.start()
        #expect(!driver.isRunning)
    }

    /// One second of ticks at 24 Hz, from the link's media clock; `keep` picks which arrive.
    private func measure(_ keep: (Int) -> Bool) -> SuitePlaybackDriver {
        let driver = SuitePlaybackDriver(onTick: { _ in true }, makeLink: { _ in nil })
        for tick in 0...24 where keep(tick) { driver.receive(target: 7000 + Double(tick) / 24) }
        return driver
    }

    @Test func aSecondOfTicksAtTwentyFourMeasuresTwentyFour() {
        #expect(measure { _ in true }.measuredFPS == 24)
    }

    @Test func everyOtherTickDroppedMeasuresTwelve() {
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
