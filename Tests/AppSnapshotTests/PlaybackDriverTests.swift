// PlaybackDriverTests.swift: LA-2's live driver against its fake (docs/blueprints/flare.md, 7.5). The same target
// timestamps fed through PlaybackDriver and straight into FlareWorkspace.tick (the Linux fake's path) land on the
// same frames; a paused workspace stops the display link; the driver times by the targets it is given, not wall time.
// `measuredFPS` (IT-9): ticks 1/24 s apart for a second measure 24, every other one dropped 12, and none before a
// second has passed or after a stop.
#if canImport(AppKit)
import AppKit
import FlareModel
import Testing

@testable import FlareApp

/// Holds the workspace the driver's closure plays, as the window's state does.
@MainActor
private final class Player {
    var model = FlareWorkspace(services: .fake())
    lazy var driver = PlaybackDriver { [weak self] target, ticker in
        self?.model.tick(target: target, ticker: &ticker) ?? false
    }

    init() {
        model.newSampleAnimation()
    }
}

@MainActor
@Suite struct PlaybackDriverTests {
    /// 2 s of 60 Hz targets, starting far from zero like the link's media clock.
    private let targets = (0...120).map { 7000 + Double($0) / 60 }

    @Test func theDriverAgreesWithTheFakeOnTheSameTicks() {
        let player = Player()
        var fake = player.model, ticker = PlaybackTicker()
        player.model.play()
        fake.play()
        #expect(player.model.canPlay)
        for target in targets {
            player.driver.receive(target: target)
            _ = fake.tick(target: target, ticker: &ticker)
            #expect(player.model.currentFrame == fake.currentFrame)
        }
        #expect(player.model.isPlaying == fake.isPlaying)
    }

    @Test func usesTheTargetTimestampNotWallTime() {
        let player = Player()
        player.model.play()
        // Two ticks a whole second apart on the link's clock, delivered back to back.
        player.driver.receive(target: 7000)
        player.driver.receive(target: 7001)
        #expect(player.model.currentFrame == player.model.playbackFPS % max(player.model.timelineFrames, 1))
    }

    @Test func stopsWhenPaused() {
        let player = Player()
        player.model.play()
        player.driver.start()
        // A headless runner has no screen and so no link; the pause still stops every tick.
        let hasScreen = NSScreen.main != nil
        #expect(player.driver.isRunning == hasScreen)
        player.driver.receive(target: 7000)
        player.model.pause()
        let frame = player.model.currentFrame
        player.driver.receive(target: 7002)
        #expect(!player.driver.isRunning && player.model.currentFrame == frame)
        player.driver.stop()
    }

    /// One second of ticks at 24 Hz, from the link's media clock; `keep` picks which arrive.
    private func measure(_ keep: (Int) -> Bool) -> PlaybackDriver {
        let driver = PlaybackDriver { _, _ in true }
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
