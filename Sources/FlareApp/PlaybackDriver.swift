// PlaybackDriver.swift: Flare's playback clock on the screen's display link (docs/blueprints/flare.md, 7.5, LA-2).
// `start(on:)` opens a link from `NSScreen.displayLink(target:selector:)` (macOS 14+) and hands each refresh's
// `targetTimestamp`, the time that frame reaches the screen, never wall time, to the `onTick` closure, which calls
// `FlareWorkspace.tick(target:ticker:)`. The driver owns the PlaybackTicker; when `onTick` returns false (paused,
// or the end of a non-looping play) it invalidates the link, so a paused document costs no refreshes. The link
// retains its target, so the owner calls `stop()` when it is done. No SwiftUI: the window starts it on play.
// `measuredFPS` (inspector-timeline IT-9) counts the targets received in the last second, the rate the screen is
// actually refreshing playback at; nil until a second of ticks has come in since the start.
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
    /// The targets received in the last second, oldest first, and the first target since the last start.
    private var recent: [Double] = []
    private var firstTarget: Double?
    /// Slack for float error at the window's edge: a tick exactly one second old falls outside it.
    private static let slack = 1e-6

    /// Whether a display link is running.
    var isRunning: Bool { link != nil }

    /// Ticks received over the last second; nil before a second of ticks has come in since the start.
    var measuredFPS: Double? {
        guard let firstTarget, let last = recent.last, last - firstTarget >= 1 - Self.slack else { return nil }
        return Double(recent.count(where: { $0 > last - 1 + Self.slack }))
    }

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
        recent.removeAll()
        firstTarget = nil
    }

    @objc private func step(_ link: CADisplayLink) {
        receive(target: link.targetTimestamp)
    }

    /// One tick at `target` seconds on the link's clock; stops the link once playback has stopped.
    func receive(target: Double) {
        record(target)
        if !onTick(target, &ticker) { stop() }
    }

    /// Keeps `target` for the measure; a target that isn't finite or later than the last is ignored.
    private func record(_ target: Double) {
        guard target.isFinite, target > recent.last ?? -.infinity else { return }
        if firstTarget == nil { firstTarget = target }
        recent.append(target)
        recent.removeAll { $0 <= target - 1 - Self.slack }
    }
}
#endif
