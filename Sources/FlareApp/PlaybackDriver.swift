// PlaybackDriver.swift: Flare's playback clock on the screen's display link (docs/blueprints/flare.md, 7.5, LA-2).
// `start(on:)` opens a link from `NSScreen.displayLink(target:selector:)` (macOS 14+) and hands each refresh's
// `targetTimestamp`, the time that frame reaches the screen, never wall time, to the `onTick` closure, which calls
// `FlareWorkspace.tick(target:ticker:)`. The driver owns the PlaybackTicker; when `onTick` returns false (paused,
// or the end of a non-looping play) it invalidates the link, so a paused document costs no refreshes. The link
// retains its target, so the owner calls `stop()` when it is done. No SwiftUI: the window starts it on play.
#if canImport(AppKit)
import AppKit
import FlareModel
import QuartzCore

@MainActor
final class PlaybackDriver: NSObject {
    /// One refresh: the target timestamp and the driver's ticker; returns whether playback is still running.
    typealias Tick = @MainActor (_ target: Double, _ ticker: inout PlaybackTicker) -> Bool

    private let onTick: Tick
    private var ticker = PlaybackTicker()
    private var link: CADisplayLink?

    /// Whether a display link is running.
    var isRunning: Bool { link != nil }

    init(onTick: @escaping Tick) {
        self.onTick = onTick
    }

    /// Starts ticking in sync with `screen` (the main screen when nil); does nothing while already running.
    func start(on screen: NSScreen? = nil) {
        guard link == nil, let screen = screen ?? NSScreen.main else { return }
        ticker.reset()
        let link = screen.displayLink(target: self, selector: #selector(step(_:)))
        link.add(to: .main, forMode: .common)
        self.link = link
    }

    /// Stops the link and forgets the ticker's baseline, so the next start counts no paused time.
    func stop() {
        link?.invalidate()
        link = nil
        ticker.reset()
    }

    @objc private func step(_ link: CADisplayLink) {
        receive(target: link.targetTimestamp)
    }

    /// One tick at `target` seconds on the link's clock; stops the link once playback has stopped.
    func receive(target: Double) {
        if !onTick(target, &ticker) { stop() }
    }
}
#endif
