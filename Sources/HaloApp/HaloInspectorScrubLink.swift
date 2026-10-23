// HaloInspectorScrubLink.swift: a TRANSFORM bar's scrub on the screen's
// refresh (CL-probe, #4275). HaloPropertyRowView hands it every pointer
// sample of a drag on its bar; HaloInspectorScrub (HaloModel) holds them. The
// first starts a link from the window's `haloRefreshLink` (HaloLiveEdit.makeLink); each refresh writes the latest
// value once through `write` (the window's HaloLiveEdit) and, under
// `-SuitePerfProbe`, records one `inspector-scrub` sample per event it shows,
// stamped shown on the next main-actor turn as HaloProbe's are. An idle
// refresh stops the link; `end()` writes what is left and stops it.
import AppKit
import HaloModel
import SuiteUI

@MainActor final class HaloInspectorScrubLink {
    private var scrub = HaloInspectorScrub()
    private var link: (any HaloRefreshLink)?
    private var write: @MainActor (Double) -> Void = { _ in }
    private var probe = HaloProbe(nil)

    /// One sample: the bar's new shown value, or nil for a drag move that
    /// kept it. `write` puts a value on screen; `probe` records what each
    /// refresh shows.
    func take(
        _ value: Double?, probe: HaloProbe, makeLink: HaloPlaybackDriver.LinkMaker,
        write: @escaping @MainActor (Double) -> Void
    ) {
        self.write = write
        self.probe = probe
        let now = ProcessInfo.processInfo.systemUptime
        switch scrub.take(value, at: HaloProbe.eventTime, now: now) {
        case .wait: break
        case .askRefresh:
            if link == nil { link = makeLink { [weak self] _ in self?.refresh() } }
            if link == nil { show(scrub.refresh(at: now)) }
        case .writeNow: show(scrub.refresh(at: now))
        }
    }

    /// The drag ended: what no refresh showed yet, then no more refreshes.
    func end() {
        stop()
        show(scrub.end())
    }

    /// One refresh of the link; an idle one stops it.
    private func refresh() {
        let frame = scrub.refresh(at: ProcessInfo.processInfo.systemUptime)
        guard !frame.isEmpty else { return stop() }
        show(frame)
    }

    private func stop() {
        link?.invalidate()
        link = nil
    }

    /// Writes `frame`'s value, then records each of its events shown once the window's update ran.
    private func show(_ frame: HaloScrubFrame) {
        if let value = frame.value { write(value) }
        guard let recorder = probe.recorder, !frame.events.isEmpty else { return }
        let events = frame.events
        Task { @MainActor in
            let shown = ProcessInfo.processInfo.systemUptime
            for event in events {
                recorder.record(ProbeSample(series: HaloProbe.inspectorScrub, eventTime: event, shownAt: shown))
            }
        }
    }
}
