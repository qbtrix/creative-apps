// HaloViewerPace.swift: a viewer drag's moves, at most one live preview write
// per display refresh (#4276), as HaloDragPacer decides: a held move (the
// latest wins) is written by a deferred task once its refresh is due, the
// exact last one on mouse-up. The refresh is the main screen's shortest, 1/60
// s without one, on the uptime clock (no display link, so a headless host
// paces the same). A held move's probe sample is stamped shown when it lands.
import AppKit
import HaloModel

@MainActor final class HaloViewerPace {
    private var pacer = HaloDragPacer(interval: HaloViewerPace.refresh)
    /// The held moves' event times, for the probe.
    private var held: [Double] = []
    private var flush: Task<Void, Never>?

    /// Seconds per refresh of the main screen; 1/60 without one.
    static var refresh: Double {
        let interval = NSScreen.main?.minimumRefreshInterval ?? 0
        return interval > 0 ? interval : 1.0 / 60
    }

    /// Whether this drag has moved yet.
    var isFresh: Bool { pacer.latest == nil }

    /// The drag moved to `point`: `write` runs on it now, or on the latest
    /// held point once its refresh is due.
    func move(to point: HaloPoint, probe: HaloProbe, write: @escaping @MainActor @Sendable (HaloPoint) -> Void) {
        let now = ProcessInfo.processInfo.systemUptime
        if probe.isOn { held.append(HaloProbe.eventTime) }
        if let next = pacer.move(to: point, now: now) { return show(next, probe: probe, write: write) }
        guard flush == nil, let due = pacer.due else { return }
        flush = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(max(due - now, 0)))
            guard let self, !Task.isCancelled else { return }
            self.flush = nil
            let at = max(ProcessInfo.processInfo.systemUptime, due)
            if let next = self.pacer.flush(now: at) { self.show(next, probe: probe, write: write) }
        }
    }

    /// Mouse-up: the drag's exact last point (nil when it never moved); the
    /// held samples are shown with it.
    func end(probe: HaloProbe) -> HaloPoint? {
        flush?.cancel()
        flush = nil
        let last = pacer.end()
        stamp(probe)
        return last
    }

    /// Escape: drops the held moves.
    func cancel() {
        flush?.cancel()
        flush = nil
        pacer.cancel()
        held = []
    }

    private func show(_ point: HaloPoint, probe: HaloProbe, write: @MainActor (HaloPoint) -> Void) {
        write(point)
        stamp(probe)
    }

    /// Each held sample, shown on the next main-actor turn, once the write has run.
    private func stamp(_ probe: HaloProbe) {
        let events = held
        held = []
        guard probe.isOn, !events.isEmpty else { return }
        Task { @MainActor in
            let shown = ProcessInfo.processInfo.systemUptime
            for event in events { probe.sample(HaloProbe.viewerDrag, event: event, shownAt: shown) }
        }
    }
}
