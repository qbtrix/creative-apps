// HaloProbe.swift: what Halo's input sites record into the window's frame
// probe (core-loop CL-8, HB-U1 to HB-U5). Each site reads SuiteUI's
// `suiteProbeRecorder` from the environment with `@Environment`, never by
// observing it, and wraps it here; without `-SuitePerfProbe` the recorder is
// nil and every call returns at once. A sample is the input event's
// timestamp (the current NSEvent's, else now on the same uptime clock) and,
// on the next main-actor turn, once the window's update has run, the time it
// was shown, as SuiteUI's ScrubField and CanvasViewport report theirs. The
// viewer drag (`viewer-drag`, plus `preview-before-mouse-up` on its first
// sample), the inspector bar scrub (`inspector-scrub`) and the ruler drag
// (`playhead-scrub`) take samples; playback (`playback`, one per frame shown
// at the refresh's target) and the lane and layer-list scrolls
// (`lanes-scroll`, `layers-scroll`) record drawn frames. Nothing here writes
// view state or the Model, so recording runs no window body.
import AppKit
import SuiteUI

@MainActor struct HaloProbe {
    static let viewerDrag = "viewer-drag", inspectorScrub = "inspector-scrub", playheadScrub = "playhead-scrub"
    static let playback = "playback", lanesScroll = "lanes-scroll", layersScroll = "layers-scroll"
    static let previewBeforeMouseUp = "preview-before-mouse-up"

    let recorder: SuiteProbeRecorder?

    init(_ recorder: SuiteProbeRecorder?) { self.recorder = recorder }

    /// Whether anything is recorded: only under `-SuitePerfProbe`.
    var isOn: Bool { recorder != nil }

    /// The current input event's timestamp, else now, on the system uptime clock.
    static var eventTime: Double { NSApp.currentEvent?.timestamp ?? ProcessInfo.processInfo.systemUptime }

    /// A sample of `series` for the event at `event`, shown at `shownAt`.
    func sample(_ series: String, event: Double, shownAt: Double) {
        recorder?.record(ProbeSample(series: series, eventTime: event, shownAt: shownAt))
    }

    /// A sample of `series` for the current event, stamped shown on the next main-actor turn.
    func sample(_ series: String) {
        guard let recorder else { return }
        let event = Self.eventTime
        Task { @MainActor in
            recorder.record(ProbeSample(series: series, eventTime: event, shownAt: ProcessInfo.processInfo.systemUptime))
        }
    }

    /// A frame of `series` drawn at `time`, by default now.
    func drew(_ series: String, at time: Double = ProcessInfo.processInfo.systemUptime) {
        recorder?.drew(series, at: time)
    }

    /// An in-app moment on `series`, stamped now.
    func mark(_ name: String, series: String) {
        recorder?.mark(name, series: series)
    }
}
