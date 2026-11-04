// PlaybackDriverTests.swift: Flare's player (FlarePlayer, on the suite's SuitePlaybackDriver; LA-2, OD-10) against its
// fake (docs/blueprints/flare.md, 7.5). The same target timestamps fed through the player on a hand-fired link and
// straight into FlareWorkspace.tick (the Linux fake's path) land on the same frames; the player never writes the
// workspace it plays; it times by the targets it is given, not wall time; a stop invalidates the link; play once
// ending stops the link and hands its clock back a turn later. `measuredFPS` itself is SuitePlaybackDriverTests'.
#if canImport(AppKit)
import AppKit
import FlareModel
import SuiteKernel
import SuiteUI
import Testing

@testable import FlareApp

@MainActor
@Suite struct PlaybackDriverTests {
    /// 2 s of 60 Hz targets, starting far from zero like the link's media clock.
    private let targets = (0...120).map { 7000 + Double($0) / 60 }

    /// A player whose links are HaloFakeLinks, and a playing sample workspace.
    private static func player() -> (FlarePlayer, FlareWorkspace, () -> HaloFakeLink?) {
        let player = FlarePlayer()
        var links: [HaloFakeLink] = []
        player.makeLink = { receive in
            let link = HaloFakeLink(receive)
            links.append(link)
            return link
        }
        var model = FlareWorkspace(services: .fake())
        model.newSampleAnimation()
        model.play()
        return (player, model, { links.last })
    }

    @Test func thePlayerAgreesWithTheFakeOnTheSameTicks() throws {
        let (player, model, link) = Self.player()
        var fake = model, ticker = PlaybackTicker()
        #expect(model.canPlay)
        player.follow(model) { _ in }
        let fired = try #require(link())
        for target in targets {
            fired.fire(target)
            _ = fake.tick(target: target, ticker: &ticker)
            #expect(player.frame == fake.currentFrame)
        }
        #expect(player.isPlaying == fake.isPlaying)
        #expect(model.currentFrame == 0, "the player plays a copy")
        player.stop()
    }

    @Test func usesTheTargetTimestampNotWallTime() throws {
        let (player, model, link) = Self.player()
        player.follow(model) { _ in }
        // Two ticks a whole second apart on the link's clock, delivered back to back.
        let fired = try #require(link())
        fired.fire(7000)
        fired.fire(7001)
        #expect(player.frame == model.playbackFPS % max(model.timelineFrames, 1))
        player.stop()
    }

    @Test func stopInvalidatesTheLinkAndClearsTheFrame() throws {
        let (player, model, link) = Self.player()
        player.follow(model) { _ in }
        let fired = try #require(link())
        fired.fire(7000)
        fired.fire(7000.5)
        player.stop()
        #expect(fired.invalidated && !player.isRunning && player.frame == nil && player.pending == nil)
    }

    @Test func playOnceEndingHandsItsClockBackATurnLater() async throws {
        let (player, seeded, link) = Self.player()
        var model = seeded
        model.setLoops(false)
        var landed: FlareWorkspace?
        player.follow(model) { landed = $0 }
        let fired = try #require(link())
        // 10 s of 60 Hz: past the end of any sample.
        for i in 0...600 { fired.fire(7000 + Double(i) / 60) }
        #expect(!player.isRunning && !player.isPlaying && player.frame == model.timelineFrames - 1)
        #expect(landed == nil, "the refresh that ends play lands nothing itself")
        try await Task.sleep(for: .milliseconds(20))
        let clock = try #require(landed)
        #expect(!clock.isPlaying && clock.currentFrame == model.timelineFrames - 1)
        player.stop()
    }
}
#endif
