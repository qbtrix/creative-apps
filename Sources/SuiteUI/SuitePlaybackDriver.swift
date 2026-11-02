// SuitePlaybackDriver.swift: the suite's one playback refresh (one-document OD-10, lead.md rule 20). It runs on a
// `SuiteRefreshLink` that calls back once per screen refresh with that refresh's target time on the media clock
// (`CACurrentMediaTime()`), never wall time, and hands each target to `onTick`. The app's Model owns the frame
// math (`PlaybackTiming` through its own tick); the driver only owns the link. When `onTick` returns false (paused,
// or the end of a play that doesn't loop) the driver stops the link, so a paused document costs no refreshes; an
// app may also call `stop()` itself. The link comes from an injectable `LinkMaker` (the app's default is
// `SuiteScreenLink.make`, the main screen's `NSScreen.displayLink`, macOS 14+), so a test fires a fake link by
// hand and never starts a real one. `measuredFPS` counts the targets received in the last second; `lastTarget`
// is the latest refresh's target, which a perf probe stamps a shown frame with. No SwiftUI.
#if canImport(AppKit)
import AppKit
import QuartzCore

/// Something that calls back once per refresh until it is invalidated.
@MainActor
public protocol SuiteRefreshLink: AnyObject {
    func invalidate()
}

@MainActor
public final class SuitePlaybackDriver {
    /// Makes a link that sends each refresh's target to its argument; nil when there is nothing to refresh on.
    public typealias LinkMaker = @MainActor (_ receive: @escaping @MainActor (Double) -> Void) -> (any SuiteRefreshLink)?
    /// One refresh at its target time; returns whether playback is still running.
    public typealias Tick = @MainActor (_ target: Double) -> Bool

    private let onTick: Tick
    private let makeLink: LinkMaker
    private var link: (any SuiteRefreshLink)?
    /// The targets received in the last second, oldest first, and the first target since the last start.
    private var recent: [Double] = []
    private var firstTarget: Double?
    /// Slack for float error at the window's edge: a tick exactly one second old falls outside it.
    private static let slack = 1e-6

    /// The latest refresh's target; nil before the first.
    public private(set) var lastTarget: Double?

    /// True while a link is attached.
    public var isRunning: Bool { link != nil }

    /// Ticks received over the last second; nil before a second of ticks has come in since the start.
    public var measuredFPS: Double? {
        guard let firstTarget, let last = recent.last, last - firstTarget >= 1 - Self.slack else { return nil }
        return Double(recent.count(where: { $0 > last - 1 + Self.slack }))
    }

    public init(onTick: @escaping Tick, makeLink: @escaping LinkMaker = SuiteScreenLink.make) {
        self.onTick = onTick
        self.makeLink = makeLink
    }

    /// Attaches a link; a second call while running, or a maker with nothing to refresh on, does nothing.
    public func start() {
        guard link == nil else { return }
        link = makeLink { [weak self] target in self?.receive(target: target) }
    }

    /// Detaches the link and forgets the measure; safe to call when it is not running.
    public func stop() {
        link?.invalidate()
        link = nil
        recent.removeAll()
        firstTarget = nil
    }

    /// One refresh at `target` seconds on the media clock; stops the link once `onTick` says playback stopped.
    public func receive(target: Double) {
        lastTarget = target
        record(target)
        if !onTick(target) { stop() }
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
public final class SuiteScreenLink: NSObject, SuiteRefreshLink {
    private let receive: @MainActor (Double) -> Void
    private var displayLink: CADisplayLink?

    /// A running link on the main screen; nil with no screen.
    public static func make(_ receive: @escaping @MainActor (Double) -> Void) -> (any SuiteRefreshLink)? {
        guard let screen = NSScreen.main else { return nil }
        let link = SuiteScreenLink(receive: receive)
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
#endif
