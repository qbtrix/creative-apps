// HaloPlaybackDriver.swift: Halo's playback refresh on the screen's display
// link (viewer-playback #37, VP-10). `start()` asks the main screen for a link
// through `NSScreen.displayLink(target:selector:)` (macOS 14+) and passes each
// refresh's `targetTimestamp`, when that frame reaches the screen on the
// media clock `CACurrentMediaTime()` reads, to `onTick`; the transport sends
// it on as `.tick(now)`, which calls `HaloProject.tick(now:)`. It never reads
// wall time. The transport stops it as soon as the Model stops playing, so a
// paused composition costs no refreshes. The link keeps its target alive, so
// whoever starts it calls `stop()`. `receive(target:)` is the seam tests use.
#if canImport(AppKit)
import AppKit
import QuartzCore

@MainActor
final class HaloPlaybackDriver: NSObject {
    private let onTick: @MainActor (Double) -> Void
    private var link: CADisplayLink?

    /// True while a display link is attached.
    var isRunning: Bool { link != nil }

    init(onTick: @escaping @MainActor (Double) -> Void) {
        self.onTick = onTick
    }

    /// Attaches a link to the main screen; a second call while running, or a
    /// call with no screen (a headless runner), does nothing.
    func start() {
        guard link == nil, let screen = NSScreen.main else { return }
        let newLink = screen.displayLink(target: self, selector: #selector(refresh(_:)))
        newLink.add(to: .main, forMode: .common)
        link = newLink
    }

    /// Detaches the link; safe to call when it is not running.
    func stop() {
        link?.invalidate()
        link = nil
    }

    @objc private func refresh(_ sender: CADisplayLink) {
        receive(target: sender.targetTimestamp)
    }

    /// One refresh at `target` seconds on the media clock.
    func receive(target: Double) {
        onTick(target)
    }
}
#endif
