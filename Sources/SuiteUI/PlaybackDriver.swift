// PlaybackDriver.swift: the suite's one display-link driver (#5077). It runs on a `RefreshLink` that calls back once
// per screen refresh with that refresh's `targetTimestamp`, the time the frame reaches the screen, never wall time,
// and hands each target with the driver's `PlaybackTicker` (SuiteKernel Playback) to `onTick`. When `onTick` returns
// false (paused, or the end of a play-once) the driver stops its link, so a paused document costs no refreshes; a
// stop also resets the ticker, so the next start counts no paused time. The app's link is `ScreenRefreshLink`, the
// main screen's `NSScreen.displayLink(target:selector:)` (macOS 14+); a window reads it from the `refreshLink`
// environment value, so a test hosting a whole window swaps in a link it fires by hand and no unit test starts a real
// one. `measuredFPS` counts the targets of the last second (the status pill's rate); nil until a second has passed.
#if canImport(AppKit)
import AppKit
import QuartzCore
import SuiteKernel
import SwiftUI

/// Something that calls back once per refresh until it is invalidated.
@MainActor
public protocol RefreshLink: AnyObject {
    func invalidate()
}

@MainActor
public final class PlaybackDriver {
    /// Makes a link that sends each refresh's target to its argument; nil when there is nothing to refresh on.
    public typealias LinkMaker = @MainActor (_ receive: @escaping @MainActor (Double) -> Void) -> (any RefreshLink)?
    /// One refresh: the target timestamp and the driver's ticker; returns whether playback is still running.
    public typealias Tick = @MainActor (_ target: Double, _ ticker: inout PlaybackTicker) -> Bool

    private let onTick: Tick
    private let makeLink: LinkMaker
    private var link: (any RefreshLink)?
    private var ticker = PlaybackTicker()
    /// The targets received in the last second, oldest first, and the first target since the last start.
    private var recent: [Double] = []
    private var firstTarget: Double?
    /// Slack for float error at the window's edge: a tick exactly one second old falls outside it.
    private static let slack = 1e-6

    /// The latest refresh's target, which a frame shown is drawn at; nil before the first.
    public private(set) var lastTarget: Double?

    /// True while a link is attached.
    public var isRunning: Bool { link != nil }

    /// Ticks received over the last second; nil before a second of ticks has come in since the start.
    public var measuredFPS: Double? {
        guard let firstTarget, let last = recent.last, last - firstTarget >= 1 - Self.slack else { return nil }
        return Double(recent.count(where: { $0 > last - 1 + Self.slack }))
    }

    public init(onTick: @escaping Tick, makeLink: @escaping LinkMaker = ScreenRefreshLink.make) {
        self.onTick = onTick
        self.makeLink = makeLink
    }

    /// Attaches a link; a second call while running, or a maker with nothing to refresh on, does nothing.
    public func start() {
        guard link == nil else { return }
        ticker.reset()
        link = makeLink { [weak self] target in self?.receive(target: target) }
    }

    /// Detaches the link and forgets the ticker's baseline and the measure; safe to call when not running.
    public func stop() {
        link?.invalidate()
        link = nil
        ticker.reset()
        recent.removeAll()
        firstTarget = nil
    }

    /// One refresh at `target` seconds on the link's clock; stops the link once playback has stopped.
    public func receive(target: Double) {
        lastTarget = target
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

/// The app's link: the main screen's display link, passing each refresh's `targetTimestamp` on. The display link
/// keeps this object alive until `invalidate()`.
@MainActor
public final class ScreenRefreshLink: NSObject, RefreshLink {
    private let receive: @MainActor (Double) -> Void
    private var displayLink: CADisplayLink?

    /// A running link on the main screen; nil with no screen (a headless runner).
    public static func make(_ receive: @escaping @MainActor (Double) -> Void) -> (any RefreshLink)? {
        guard let screen = NSScreen.main else { return nil }
        let link = ScreenRefreshLink(receive: receive)
        let display = screen.displayLink(target: link, selector: #selector(refresh(_:)))
        display.add(to: .main, forMode: .common)
        link.displayLink = display
        return link
    }

    private init(receive: @escaping @MainActor (Double) -> Void) {
        self.receive = receive
        super.init()
    }

    public func invalidate() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func refresh(_ sender: CADisplayLink) {
        receive(sender.targetTimestamp)
    }
}

extension EnvironmentValues {
    /// The link a window's playback and scrubs pace on: the main screen's display link. A plain key rather than
    /// `@Entry`, as in Glass.swift.
    public var refreshLink: PlaybackDriver.LinkMaker {
        get { self[RefreshLinkKey.self] }
        set { self[RefreshLinkKey.self] = newValue }
    }
}

private struct RefreshLinkKey: EnvironmentKey {
    static var defaultValue: PlaybackDriver.LinkMaker { ScreenRefreshLink.make }
}
#endif
