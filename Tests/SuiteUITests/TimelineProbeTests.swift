// TimelineProbeTests.swift (findings #2722, #2723, #2725): the timeline's latency samples reach the window's
// `suite.perf`. A key drag records one `key-drag` sample per pointer sample (not only per frame step), a scrub one
// `timeline-scrub` sample per frame it sends, and the window's SuiteProbeRecorder hands the strip its probe, so the
// SP3 and SP8 journeys read 60 or more samples where they read none. macOS only.
import AppKit
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor @Suite struct TimelineProbeTests {
    private static let mapping = FrameMapping(duration: 400, frameWidth: 4)
    private static let track = TimelineTrack(
        id: "a", name: "A", keys: [40, 100].map { TimelineKey(frame: $0, shape: .linear) }, spans: [], pickedFrames: [40])

    /// Every sample the probe heard.
    @MainActor private final class Samples {
        var all: [ProbeSample] = []
        var probe: TimelineFadeMark { TimelineFadeMark(record: { _ in }, sample: { self.all.append($0) }) }
    }

    @Test func aKeyDragRecordsASamplePerPointerSample() async throws {
        let samples = Samples()
        let view = TimelineLanesView(frame: NSRect(x: 0, y: 0, width: 1_600, height: SuiteSize.timelineLane))
        let pointer = TimelineLanePointer<String>()
        pointer.configure(
            track: Self.track, mapping: Self.mapping, playhead: 0,
            actions: TimelineLaneActions(onSelectKeyframe: { _, _ in }, onSelectTrack: { _ in }, onPickKeyframe: { _, _, _ in }),
            extras: TimelineLanePointerExtras(focus: nil, pill: .constant(nil), mark: samples.probe))
        view.pointer = pointer
        view.update([TimelineLaneDrawing(Self.track, mapping: Self.mapping)])
        let start = CGPoint(x: tickX(Self.mapping, 40), y: SuiteSize.timelineLane / 2)
        view.press(at: start, flags: [])
        for step in 1...80 { view.drag(to: CGPoint(x: start.x + CGFloat(step), y: start.y)) }
        // Each sample lands on a later main-actor turn: suspend so those turns run.
        for _ in 0..<50 where samples.all.count < 80 { try await Task.sleep(for: .milliseconds(20)) }
        #expect(samples.all.count == 80, "80 pointer samples recorded \(samples.all.count)")
        #expect(samples.all.allSatisfy { $0.series == TimelineFadeMark.keyDragSeries && $0.shownAt >= $0.eventTime })
        view.release(at: CGPoint(x: start.x + 80, y: start.y))
    }

    @Test func theScrubSenderSaysWhenItSentAFrame() {
        let sender = TimelineScrubSender()
        var sent: [Int] = []
        let first = sender.send(5, from: 5) { sent.append($0) }
        let second = sender.send(6, from: 5) { sent.append($0) }
        let third = sender.send(6, from: 5) { sent.append($0) }
        #expect([first, second, third] == [false, true, false])
        #expect(sent == [6])
    }

    @Test func theWindowsRecorderTakesTheTimelinesSamples() {
        let recorder = SuiteProbeRecorder()
        recorder.timelineProbe.sample(ProbeSample(series: TimelineFadeMark.scrubSeries, eventTime: 1, shownAt: 1.01))
        recorder.timelineProbe.record(ProbeMark(name: "fade-start", series: "timeline-hover", time: 1))
        let document = recorder.probe.document(refreshInterval: 1.0 / 120)
        #expect(document.samples.map(\.series) == [TimelineFadeMark.scrubSeries])
        #expect(document.marks.map(\.series) == ["timeline-hover"])
    }
}
