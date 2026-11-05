// FlarePlayer.swift: the window's player, Flare's twin of Design's DesignPlayer (#5077 tracks the shared one). It
// holds the suite's one display-link driver (SuitePlaybackDriver), SuiteKernel's PlaybackTicker and `clock`, a copy of
// the window's workspace taken when play starts that only the ticks advance (`FlareWorkspace.tick`). Each refresh
// puts the clock's frame in `frame`, which only FlareCanvas reads (the stage and the timeline draw the window's
// workspace at that frame), so a tick runs the canvas and never the window, and never writes the workspace: no undo
// step, autosave or unsaved-change marker. The window lands the clock as its playhead (`landPlayback`) before any
// intent acts, so an edit acts at the frame on screen, then `follow`s the result: still playing re-seeds the clock
// from the window's workspace, stopped clears it. Play once ending keeps its last frame shown and lands it through
// `ended` on the next main-actor turn, so the refresh that ends play never runs the window.
// A reference type, so the window's body reads nothing a tick changes. The link comes from the `flareRefreshLink`
// environment (the screen's display link, or one a test fires by hand), handed over once by FlareWindow's
// RefreshLinkHandoff, so the window body never reads that closure.
import FlareModel
import Observation
import SuiteKernel
import SuiteUI
import SwiftUI

@MainActor @Observable final class FlarePlayer {
    /// The frame playback shows; nil while nothing plays or waits to land.
    private(set) var frame: Int?
    /// Whether the clock still plays; false once play once ended, until it lands.
    private(set) var isPlaying = false
    @ObservationIgnored private var clock: FlareWorkspace?
    @ObservationIgnored private var ticker = PlaybackTicker()
    @ObservationIgnored private var driver: SuitePlaybackDriver?
    @ObservationIgnored private var landing: Task<Void, Never>?
    /// The window's `flareRefreshLink`, set by FlareWindow's RefreshLinkHandoff once it appears.
    @ObservationIgnored var makeLink: SuitePlaybackDriver.LinkMaker = SuiteScreenLink.make

    /// The clock to land as the window's playhead before an intent acts; nil when nothing plays or waits to land.
    var pending: FlareWorkspace? { clock }
    /// The rate the link measured over the last second; nil while paused.
    var measuredFPS: Double? { driver?.measuredFPS }
    /// True while the display link runs.
    var isRunning: Bool { driver != nil }

    /// Plays on from `model` while it plays, re-seeding the clock and keeping the link running; stops otherwise.
    /// `ended` gets the clock when play once ends.
    func follow(_ model: FlareWorkspace, ended: @escaping @MainActor (FlareWorkspace) -> Void) {
        guard model.isPlaying else { return stop() }
        landing?.cancel()
        landing = nil
        clock = model
        if frame != model.currentFrame { frame = model.currentFrame }
        if !isPlaying { isPlaying = true }
        guard driver == nil else { return }
        ticker.reset()
        let driver = SuitePlaybackDriver(onTick: { [weak self] target in
            self?.tick(target, ended: ended) ?? false
        }, makeLink: makeLink)
        self.driver = driver
        driver.start()
    }

    /// Stops the link and forgets the clock, so the canvas draws the window's playhead again.
    func stop() {
        driver?.stop()
        driver = nil
        landing?.cancel()
        landing = nil
        clock = nil
        if frame != nil { frame = nil }
        if isPlaying { isPlaying = false }
    }

    /// One refresh: advances the clock and shows its frame; returns false (the driver stops) once play once ends.
    private func tick(_ target: Double, ended: @escaping @MainActor (FlareWorkspace) -> Void) -> Bool {
        let playing = clock?.tick(target: target, ticker: &ticker) ?? false
        guard let clock else { return false }
        if frame != clock.currentFrame { frame = clock.currentFrame }
        guard !playing else { return true }
        driver = nil
        isPlaying = false
        landing = Task { @MainActor [weak self] in
            guard !Task.isCancelled, self?.clock != nil else { return }
            ended(clock)
        }
        return false
    }
}

extension FlareWindow {
    /// Lands the frame on screen as the playhead, so the intent that follows acts at it; nothing when idle.
    func landPlayback() {
        if let clock = player.pending { model.landPlayback(from: clock) }
    }

    /// Plays on from the workspace while it plays (an intent may have moved the playhead or the loop), else stops.
    func followPlayback() {
        player.follow(model) { clock in
            model.landPlayback(from: clock)
            followPlayback()
        }
    }

    /// Starts or stops the player when the workspace starts or stops playing without an intent (a load, a live
    /// command); a running player keeps its clock.
    func syncPlayback() {
        if !model.isPlaying { player.stop() } else if !player.isRunning, player.pending == nil { followPlayback() }
    }

    /// The workspace at the frame on screen, for the live window's reads.
    var playbackShown: FlareWorkspace {
        player.frame.map { model.showing(frame: $0, playing: player.isPlaying) } ?? model
    }
}

/// Hands the window's `flareRefreshLink` to `player` once it appears. Only this modifier's body reads the closure,
/// so an environment change re-runs it, not FlareWindow's body.
struct RefreshLinkHandoff: ViewModifier {
    let player: FlarePlayer
    @Environment(\.flareRefreshLink) private var makeLink

    func body(content: Content) -> some View {
        content.onAppear { player.makeLink = makeLink }
    }
}

extension EnvironmentValues {
    /// The link Flare's player runs on: the main screen's display link. A test hosting the window swaps in a link it
    /// fires by hand; no unit test starts a real one.
    @Entry var flareRefreshLink: SuitePlaybackDriver.LinkMaker = SuiteScreenLink.make
}
