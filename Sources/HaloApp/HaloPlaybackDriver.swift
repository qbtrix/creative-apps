// HaloPlaybackDriver.swift: Halo's playback refresh (viewer-playback #37,
// VP-10). The driver runs on a `HaloRefreshLink` that calls back once per
// screen refresh with that refresh's target time on the media clock
// `CACurrentMediaTime()` reads; it passes each target to `onTick`, and the
// transport sends it on as `.tick(now)`, which calls `HaloProject.tick(now:)`.
// It never reads wall time. The app's link is `HaloScreenLink`, the main
// screen's `NSScreen.displayLink(target:selector:)` (macOS 14+), read from
// the `haloRefreshLink` environment value so a test hosting the whole window
// can swap in a link it fires by hand; no unit test ever starts a real one.
// The transport stops the driver as soon as the Model stops playing, so a
// paused composition costs no refreshes.
#if canImport(AppKit)
import AppKit
import QuartzCore
import SwiftUI

extension EnvironmentValues {
    /// The link the transport's driver plays on: the main screen's display link.
    @Entry var haloRefreshLink: HaloPlaybackDriver.LinkMaker = HaloScreenLink.make
}

/// Something that calls back once per refresh until it is invalidated.
@MainActor
protocol HaloRefreshLink: AnyObject {
    func invalidate()
}

@MainActor
final class HaloPlaybackDriver {
    /// Makes a link that sends each refresh's target to its argument; nil
    /// when there is nothing to refresh on (no screen).
    typealias LinkMaker = @MainActor (_ receive: @escaping @MainActor (Double) -> Void) -> (any HaloRefreshLink)?

    private let onTick: @MainActor (Double) -> Void
    private let makeLink: LinkMaker
    private var link: (any HaloRefreshLink)?

    /// True while a link is attached.
    var isRunning: Bool { link != nil }

    init(onTick: @escaping @MainActor (Double) -> Void, makeLink: @escaping LinkMaker = HaloScreenLink.make) {
        self.onTick = onTick
        self.makeLink = makeLink
    }

    /// Attaches a link; a second call while running, or a maker with nothing
    /// to refresh on, does nothing.
    func start() {
        guard link == nil else { return }
        link = makeLink { [weak self] target in self?.receive(target: target) }
    }

    /// Detaches the link; safe to call when it is not running.
    func stop() {
        link?.invalidate()
        link = nil
    }

    /// One refresh at `target` seconds on the media clock.
    func receive(target: Double) {
        onTick(target)
    }
}

/// The app's link: the main screen's display link, passing each refresh's
/// `targetTimestamp` on. The display link keeps this object alive until
/// `invalidate()`.
@MainActor
final class HaloScreenLink: NSObject, HaloRefreshLink {
    private let receive: @MainActor (Double) -> Void
    private var displayLink: CADisplayLink?

    /// A running link on the main screen; nil with no screen.
    static func make(_ receive: @escaping @MainActor (Double) -> Void) -> (any HaloRefreshLink)? {
        guard let screen = NSScreen.main else { return nil }
        let link = HaloScreenLink(receive: receive)
        let display = screen.displayLink(target: link, selector: #selector(refresh(_:)))
        display.add(to: .main, forMode: .common)
        link.displayLink = display
        return link
    }

    private init(receive: @escaping @MainActor (Double) -> Void) {
        self.receive = receive
        super.init()
    }

    func invalidate() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func refresh(_ sender: CADisplayLink) {
        receive(sender.targetTimestamp)
    }
}
#endif
