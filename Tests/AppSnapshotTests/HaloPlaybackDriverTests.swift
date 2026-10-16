// HaloPlaybackDriverTests.swift: VP-10's playback driver (viewer-playback
// #37). The same target timestamps fired through HaloPlaybackDriver's link
// and sent straight into HaloProject.tick(now:) land on the same frames; the
// frames follow the targets, not wall time; and a paused model stops the
// link, the way HaloTransport follows `playback.playing`. Every test runs on
// a HaloFakeLink fired by hand: none starts a real display link, which the
// headless CI runner can't serve. macOS only.
#if canImport(AppKit)
import AppKit
import HaloModel
import Testing

@testable import HaloApp

/// A link the test fires by hand; after `invalidate()` it fires nothing.
@MainActor
final class HaloFakeLink: HaloRefreshLink {
    private let receive: @MainActor (Double) -> Void
    private(set) var invalidated = false

    init(_ receive: @escaping @MainActor (Double) -> Void) { self.receive = receive }

    func invalidate() { invalidated = true }

    func fire(_ target: Double) {
        if !invalidated { receive(target) }
    }
}

/// Holds the project the driver plays, as the window's state does, and stops
/// the driver once the Model stops playing, as the transport does. Every link
/// the driver asks for is a HaloFakeLink, kept in `links`.
@MainActor
private final class HaloPlayer {
    var model: HaloProject
    private(set) var links: [HaloFakeLink] = []
    // Typed, so the closures' own `driver` doesn't make its inference circular.
    lazy var driver: HaloPlaybackDriver = HaloPlaybackDriver(
        onTick: { [weak self] now in
            guard let self else { return }
            self.model.tick(now: now)
            if !self.model.playback.playing { self.driver.stop() }
        },
        makeLink: { [weak self] receive in
            let link = HaloFakeLink(receive)
            self?.links.append(link)
            return link
        })

    init() throws {
        model = HaloProject(services: .fake, document: try #require(HaloFixtures.project("three-layers")))
    }

    /// The link the driver is running on, if it started one.
    var link: HaloFakeLink? { links.last }
}

// The limit bounds a real hang, not the work: these tests share the main
// actor with every @MainActor snapshot suite in this process, so on CI they
// can queue for minutes before running (dev run 38743186679: 185 s queued,
// as Flare's PlaybackDriverTests waited 314 s in run 38738075349). The bodies
// fire a HaloFakeLink by hand and never wait (#1155).
@MainActor
@Suite(.timeLimit(.minutes(10))) struct HaloPlaybackDriverTests {
    /// 3 s of 60 Hz targets, far from zero like the link's media clock.
    private let targets = (1...180).map { 5000 + Double($0) / 60 }

    @Test func theDriverAgreesWithTickOnTheSameTargets() throws {
        let player = try HaloPlayer()
        var direct = player.model
        player.model.play(at: 5000)
        direct.play(at: 5000)
        player.driver.start()
        let link = try #require(player.link)
        #expect(player.model.playback.playing)
        for target in targets {
            link.fire(target)
            direct.tick(now: target)
            #expect(player.model.selectedComposition?.playheadFrame == direct.selectedComposition?.playheadFrame)
        }
        #expect(player.model.playback == direct.playback)
        player.driver.stop()
    }

    @Test func framesFollowTheTargetsNotWallTime() throws {
        let player = try HaloPlayer()
        player.model.play(at: 5000)
        player.driver.start()
        // One second apart on the link's clock, fired back to back.
        try #require(player.link).fire(5001)
        let fps = try #require(player.model.selectedComposition).framesPerSecond
        #expect(player.model.selectedComposition?.playheadFrame == fps)
        player.driver.stop()
    }

    @Test func aPausedModelStopsTheLink() throws {
        let player = try HaloPlayer()
        player.model.play(at: 5000)
        player.driver.start()
        let link = try #require(player.link)
        #expect(player.driver.isRunning)
        link.fire(5000.5)
        player.model.pause()
        let frame = player.model.selectedComposition?.playheadFrame
        link.fire(5002)
        #expect(!player.driver.isRunning)
        #expect(link.invalidated)
        #expect(player.model.selectedComposition?.playheadFrame == frame)
        // An invalidated link fires nothing more.
        link.fire(5003)
        #expect(player.model.selectedComposition?.playheadFrame == frame)
    }

    @Test func startIsOnceAndStopIsSafe() throws {
        let player = try HaloPlayer()
        player.driver.stop()
        #expect(!player.driver.isRunning)
        player.driver.start()
        player.driver.start()
        #expect(player.links.count == 1)
        player.driver.stop()
        #expect(!player.driver.isRunning)
        player.driver.start()
        #expect(player.links.count == 2)
        player.driver.stop()
    }

    @Test func nothingToRefreshOnLeavesTheDriverStopped() {
        let driver = HaloPlaybackDriver(onTick: { _ in }, makeLink: { _ in nil })
        driver.start()
        #expect(!driver.isRunning)
    }
}
#endif
