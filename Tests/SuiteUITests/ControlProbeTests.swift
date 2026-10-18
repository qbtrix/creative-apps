// ControlProbeTests.swift: `.suiteProbes()` hands scrub fields, chips and
// curve editors the window's probes under -SuitePerfProbe and none without
// it, and those probes record samples and marks into the recorder
// `suite.perf` publishes (SP1, SP6, SP7, SJ20; inspector-controls IC-14b).
// macOS only.
import AppKit
import Foundation
@testable import SuiteUI
import SwiftUI
import Testing

@Suite struct ControlProbeTests {
    @MainActor @Test func theRecorderKeepsSamplesAndMarks() {
        let recorder = SuiteProbeRecorder()
        recorder.scrubProbe.record(ScrubProbe.sample(ScrubProbe.barSeries, eventTime: 1, shownAt: 2))
        recorder.chipProbe.sample(ProbeSample(series: ChipProbe.pressSeries, eventTime: 3, shownAt: 4))
        recorder.curveProbe.record(CurveProbe.sample(eventTime: 5, shownAt: 6))
        recorder.chipProbe.record(ProbeMark(name: "fade-start", series: ChipProbe.fadeSeries, time: 7))
        recorder.curveProbe.mark(ProbeMark(name: "preview-stopped", series: CurveProbe.previewSeries, time: 8))
        let series: [String] = recorder.probe.samples.map(\.series)
        let expected: [String] = [ScrubProbe.barSeries, ChipProbe.pressSeries, CurveProbe.dragSeries]
        #expect(series == expected)
        let marks: [String] = recorder.probe.marks.map(\.name)
        let expectedMarks: [String] = ["fade-start", "preview-stopped"]
        #expect(marks == expectedMarks)
    }

    @MainActor @Test func theHostSetsControlProbesOnlyUnderTheFlag() {
        let flagged = Self.probes(arguments: [SuiteFrameProbe.launchFlag])
        #expect(flagged.scrub && flagged.chip && flagged.curve)
        let plain = Self.probes(arguments: [])
        #expect(!plain.scrub && !plain.chip && !plain.curve)
    }

    /// Which control probes a view inside `.suiteProbes(arguments:)` reads once hosted.
    @MainActor static func probes(arguments: [String]) -> SeenControlProbes {
        let seen = SeenControlProbes()
        let host = NSHostingView(rootView: ControlProbeReader(seen: seen).suiteProbes(arguments: arguments))
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 200, height: 100), styleMask: [.titled], backing: .buffered,
            defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        host.layoutSubtreeIfNeeded()
        return seen
    }
}

@MainActor final class SeenControlProbes {
    var scrub = false
    var chip = false
    var curve = false
}

private struct ControlProbeReader: View {
    let seen: SeenControlProbes
    @Environment(\.scrubProbe) private var scrub
    @Environment(\.chipProbe) private var chip
    @Environment(\.curveProbe) private var curve

    var body: some View {
        Text(verbatim: "Controls").onAppear {
            seen.scrub = scrub != nil
            seen.chip = chip != nil
            seen.curve = curve != nil
        }
    }
}
