// DesignPlayer+Kernel.swift: the window's player (one-document OD-11). It holds the DesignTransport, the
// suite's one display-link driver (SuitePlaybackDriver) and a PlaybackTicker reset on each play. Each refresh
// plays the seconds since the last one and puts the frame in DesignLiveDrag's `playingFrame`, which only the
// canvas reads, so a tick runs the canvas and never the window, and never writes the workspace: no history,
// autosave or saved-marker change. Pause lands the frame once as the workspace's playhead (shown state), so an
// edit acts at the frame on screen; stop lands nil, the rest pose; play once ending lands its last frame. A
// timeline scrub shows its frame the same way and lands it once the drag rests (`scrub`).
// A reference type, so the window's body reads nothing that a tick changes. The link comes from the
// `designRefreshLink` environment (the screen's display link, or one a test fires by hand), which
// DesignWindow's RefreshLinkHandoff sets as `makeLink` once it appears: the window body never reads that
// closure, since SwiftUI can't compare closures and every environment change (a sheet opening) would re-run it.
import DesignModel
import SuiteKernel
import SuiteUI
import SwiftUI

@MainActor final class DesignPlayer {
    private var transport = DesignTransport()
    private var ticker = PlaybackTicker()
    private var driver: SuitePlaybackDriver?
    /// A scrub's frame until it lands as the playhead.
    private var scrubbed: Int?
    private var settle: Task<Void, Never>?
    /// The window's `designRefreshLink`, set by DesignWindow's RefreshLinkHandoff once it appears.
    var makeLink: SuitePlaybackDriver.LinkMaker = SuiteScreenLink.make

    var isPlaying: Bool { transport.isPlaying }
    /// Playing, or a scrub not landed yet: an edit lands the frame first.
    var isActive: Bool { transport.isPlaying || scrubbed != nil }

    /// Plays `model` from its playhead on `live`'s canvas; `ended` gets the frame when play once ends.
    func play(_ model: DesignWorkspace, live: DesignLiveDrag, ended: @escaping @MainActor (Int?) -> Void) {
        driver?.stop()
        let time = model.time
        transport.loops = live.playLoops
        transport.play(from: model.playhead, time: time)
        ticker.reset()
        live.playingFrame = transport.frame
        live.isPlaying = true
        let driver = SuitePlaybackDriver(onTick: { [weak self, weak live] target in
            guard let self, let live else { return false }
            if let seconds = self.ticker.elapsed(toTarget: target) {
                let frame = self.transport.tick(by: seconds, time: time)
                if live.playingFrame != frame { live.playingFrame = frame }
            }
            if !self.transport.isPlaying { ended(self.halt(stopping: false, live: live)) }
            return self.transport.isPlaying
        }, makeLink: makeLink)
        self.driver = driver
        driver.start()
    }

    /// Stops the link and clears the canvas's frame; the frame to land as the playhead (nil after a stop).
    func halt(stopping: Bool, live: DesignLiveDrag) -> Int? {
        driver?.stop()
        driver = nil
        settle?.cancel()
        settle = nil
        if stopping { transport.stop() } else { transport.pause() }
        let frame = stopping ? nil : scrubbed ?? transport.frame
        scrubbed = nil
        live.playingFrame = nil
        live.isPlaying = false
        return frame
    }

    /// Shows `frame` on the canvas and the timeline now (playback pauses) and lands it through `land` once
    /// the scrub has rested `settleSeconds`, so a ruler drag runs the window once, not per step.
    func scrub(to frame: Int, live: DesignLiveDrag, land: @escaping @MainActor (Int?) -> Void) {
        if transport.isPlaying {
            driver?.stop()
            driver = nil
            transport.pause()
            live.isPlaying = false
        }
        scrubbed = frame
        live.playingFrame = frame
        settle?.cancel()
        settle = Task { @MainActor [weak self, weak live] in
            try? await Task.sleep(for: .seconds(Self.settleSeconds))
            guard !Task.isCancelled, let self, let live else { return }
            land(self.halt(stopping: false, live: live))
        }
    }

    static let settleSeconds = 0.15
}

extension EnvironmentValues {
    /// The link Design's player runs on: the main screen's display link. A test hosting the window swaps in a
    /// link it fires by hand; no unit test starts a real one.
    @Entry var designRefreshLink: SuitePlaybackDriver.LinkMaker = SuiteScreenLink.make
}
