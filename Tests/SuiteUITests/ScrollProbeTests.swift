// ScrollProbeTests.swift: `.suiteProbes()` hands grids and layer lists the
// window's GridProbe under -SuitePerfProbe and none without it, and that
// probe records drawn frames on `grid-scroll` and `layers-scroll` into the
// recorder `suite.perf` publishes (SP4, lists-and-layers LL-15b). macOS only.
import AppKit
import Foundation
@testable import SuiteUI
import SwiftUI
import Testing

@Suite struct ScrollProbeTests {
    @MainActor @Test func theRecorderKeepsFramesPerSeries() {
        let recorder = SuiteProbeRecorder()
        for i in 0..<3 { recorder.gridProbe.drew(GridProbe.scrollSeries, Double(i) / 60) }
        recorder.gridProbe.drew(GridProbe.layersScrollSeries, 1)
        recorder.gridProbe.drew(GridProbe.layersScrollSeries, .nan)
        let grid: [Double] = [0, 1.0 / 60, 2.0 / 60]
        let layers: [Double] = [1]
        #expect(recorder.probe.drawn[GridProbe.scrollSeries] == grid)
        #expect(recorder.probe.drawn["layers-scroll"] == layers)
        #expect(recorder.probe.intervals(of: "grid-scroll", refreshInterval: 1.0 / 60).count == 2)
    }

    @MainActor @Test func theHostSetsAProbeOnlyUnderTheFlag() {
        let flagged = Self.probe(arguments: [SuiteFrameProbe.launchFlag])
        #expect(flagged != nil)
        #expect(Self.probe(arguments: []) == nil)
        #expect(Self.probe(arguments: ["FlareApp"]) == nil)
    }

    /// The GridProbe a view inside `.suiteProbes(arguments:)` reads once hosted.
    @MainActor static func probe(arguments: [String]) -> GridProbe? {
        let seen = SeenProbe()
        let host = NSHostingView(rootView: ProbeReader(seen: seen).suiteProbes(arguments: arguments))
        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 200, height: 100), styleMask: [.titled], backing: .buffered,
            defer: false)
        window.contentView = host
        host.layoutSubtreeIfNeeded()
        RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        host.layoutSubtreeIfNeeded()
        return seen.probe
    }
}

@MainActor private final class SeenProbe {
    var probe: GridProbe?
}

private struct ProbeReader: View {
    let seen: SeenProbe
    @Environment(\.gridProbe) private var probe

    var body: some View {
        Text(verbatim: "Grid").onAppear { seen.probe = probe }
    }
}
