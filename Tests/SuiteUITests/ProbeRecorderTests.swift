// ProbeRecorderTests.swift: `.suiteProbes()` hands app views the window's
// SuiteProbeRecorder as `suiteProbeRecorder` under -SuitePerfProbe and nil
// without it; what a view records through it lands in the probe `suite.perf`
// publishes, without running the recording view's body again (HB-U1..U4,
// #3401). SuiteExportSheet marks `progress-shown` on its id prefix when its
// progress row appears (HB-U5, QB-L9). macOS only.
import AppKit
import Foundation
import SuiteKernel
@testable import SuiteUI
import SwiftUI
import Testing

@MainActor @Suite struct ProbeRecorderTests {
    @Test func aViewRecordsSamplesAndAMarkIntoTheWindowsProbe() throws {
        let seen = SeenRecorder()
        let host = Self.host(RecorderReader(seen: seen), arguments: [SuiteFrameProbe.launchFlag])
        let recorder = try #require(seen.recorder)
        let bodies = seen.bodies
        for i in 0..<3 { recorder.record(ProbeSample(series: "viewer-drag", eventTime: Double(i), shownAt: Double(i) + 0.01)) }
        recorder.mark("preview-before-mouse-up", series: "viewer-drag")
        recorder.drew("playback", at: 1)
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        host.layoutSubtreeIfNeeded()
        let document = recorder.probe.document(refreshInterval: SuiteFrameProbe.fallbackRefreshInterval)
        #expect(document.samples.count == 3 && document.samples.allSatisfy { $0.series == "viewer-drag" })
        #expect(document.marks.map(\.name) == ["preview-before-mouse-up"] && document.marks.first?.series == "viewer-drag")
        #expect(document.drawn["playback"] == [1])
        #expect(seen.bodies == bodies, "recording ran the recording view's body")
    }

    @Test func withoutTheFlagTheRecorderIsNil() {
        let seen = SeenRecorder()
        _ = Self.host(RecorderReader(seen: seen), arguments: [])
        #expect(seen.appeared && seen.recorder == nil)
    }

    @Test func theExportSheetMarksProgressShown() throws {
        let seen = SeenRecorder()
        let readout = ExportSheetRows(
            ExportRun<ExportPick>.running(ExportPick(format: "png"), done: 0, total: 4),
            formats: GalleryEditorKernelChrome.formats) { $0 }
        let sheet = VStack {
            RecorderReader(seen: seen)
            SuiteExportSheet(
                readout, formats: GalleryEditorKernelChrome.formats, idPrefix: "halo.render", onFormat: { _ in },
                onScale: { _ in }, onQuality: { _ in }, onExport: {}, onClose: {}, options: { EmptyView() })
        }
        _ = Self.host(sheet, arguments: [SuiteFrameProbe.launchFlag])
        let recorder = try #require(seen.recorder)
        #expect(spinUntil { !recorder.probe.marks.isEmpty })
        #expect(recorder.probe.marks.map(\.name) == ["progress-shown"] && recorder.probe.marks.first?.series == "halo.render")
    }

    /// Hosts `view` inside `.suiteProbes(arguments:)` in a window and lets it appear.
    static func host(_ view: some View, arguments: [String]) -> NSView {
        let host = NSHostingView(rootView: view.suiteProbes(arguments: arguments))
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 600, height: 400), styleMask: [.titled], backing: .buffered,
            defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        host.layoutSubtreeIfNeeded()
        return host
    }
}

@MainActor private final class SeenRecorder {
    var recorder: SuiteProbeRecorder?
    var appeared = false
    var bodies = 0
}

private struct RecorderReader: View {
    let seen: SeenRecorder
    @Environment(\.suiteProbeRecorder) private var recorder

    var body: some View {
        seen.bodies += 1
        return Text(verbatim: "Reader").onAppear { (seen.recorder, seen.appeared) = (recorder, true) }
    }
}
