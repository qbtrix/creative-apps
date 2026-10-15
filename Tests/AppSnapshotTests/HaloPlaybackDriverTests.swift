// HaloPlaybackDriverTests.swift: VP-10's display-link driver (viewer-playback
// #37). The same target timestamps sent through HaloPlaybackDriver and
// straight into HaloProject.tick(now:) land on the same frames; the frames
// follow the targets, not wall time; and a paused model stops the link, the
// way HaloTransport follows `playback.playing`. macOS only.
#if canImport(AppKit)
import AppKit
import HaloModel
import Testing

@testable import HaloApp

/// Holds the project the driver plays, as the window's state does, and stops
/// the driver once the Model stops playing, as the transport does.
@MainActor
private final class HaloPlayer {
    var model: HaloProject
    // Typed, so the closure's own `driver` doesn't make its inference circular.
    lazy var driver: HaloPlaybackDriver = HaloPlaybackDriver { [weak self] now in
        guard let self else { return }
        self.model.tick(now: now)
        if !self.model.playback.playing { self.driver.stop() }
    }

    init() throws {
        model = HaloProject(services: .fake, document: try #require(HaloFixtures.project("three-layers")))
    }
}

@MainActor
@Suite struct HaloPlaybackDriverTests {
    /// 3 s of 60 Hz targets, far from zero like the link's media clock.
    private let targets = (1...180).map { 5000 + Double($0) / 60 }

    @Test func theDriverAgreesWithTickOnTheSameTargets() throws {
        let player = try HaloPlayer()
        var direct = player.model
        player.model.play(at: 5000)
        direct.play(at: 5000)
        #expect(player.model.playback.playing)
        for target in targets {
            player.driver.receive(target: target)
            direct.tick(now: target)
            #expect(player.model.selectedComposition?.playheadFrame == direct.selectedComposition?.playheadFrame)
        }
        #expect(player.model.playback == direct.playback)
    }

    @Test func framesFollowTheTargetsNotWallTime() throws {
        let player = try HaloPlayer()
        player.model.play(at: 5000)
        // One second apart on the link's clock, delivered back to back.
        player.driver.receive(target: 5001)
        let fps = try #require(player.model.selectedComposition).framesPerSecond
        #expect(player.model.selectedComposition?.playheadFrame == fps)
    }

    @Test func aPausedModelStopsTheLink() throws {
        let player = try HaloPlayer()
        player.model.play(at: 5000)
        player.driver.start()
        // A headless runner has no screen and so no link.
        #expect(player.driver.isRunning == (NSScreen.main != nil))
        player.driver.receive(target: 5000.5)
        player.model.pause()
        let frame = player.model.selectedComposition?.playheadFrame
        player.driver.receive(target: 5002)
        #expect(!player.driver.isRunning)
        #expect(player.model.selectedComposition?.playheadFrame == frame)
        player.driver.stop()
    }
}
#endif
