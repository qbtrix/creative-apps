// RenderBudgetHaloProbeTests.swift: the frame probe's render budget
// (Tests/render-budgets.md; packet docs/blueprints/halo/features/core-loop.md,
// Quality tests) on the real window, through the harness
// (RenderBudgetHarness.swift). With `-SuitePerfProbe` on (the window wrapped
// in `.suiteProbes(arguments:)`, whose recorder a hidden reader hands the
// test), recording a sample runs no window body: a 120-sample viewer drag of
// Floor on `-HaloSample keyed` stays at RenderBudgetHaloTests' bound of 3
// window bodies and one second of 120 Hz playback (HaloWindowPlaybackTests'
// fake link) at 24 + 6. Each also checks the probe got its series: the drag's
// `viewer-drag` samples and `preview-before-mouse-up` mark, playback's
// `playback` frames. `bodies` gates the counts (CL-9); `timing` stays
// report-only until the supervisor lists it in Tests/perf-suites.txt. Nested
// in BodyCountSuites, as every suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import HaloModel
import SwiftUI
import Testing

@testable import HaloApp
@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetHaloProbeTests {
        /// render: probe on, 120-sample viewer drag ≤ 3 window bodies (gate).
        static let dragSamples = 120, dragBodies = 3
        /// render: probe on, 1 s of playback ≤ 24 frames + 6 (gate).
        static let playbackBodies = 24 + 6

        @Test(.timeLimit(.minutes(3))) func bodies() async throws {
            #if DEBUG
            let (drag, dragProbe) = try await Self.drag()
            expectBodies(drag, atMost: Self.dragBodies, target: Self.dragBodies)
            #expect(
                dragProbe.samples.contains { $0.series == HaloProbe.viewerDrag },
                "the viewer drag recorded no viewer-drag sample: \(dragProbe.samples.count) samples")
            #expect(
                dragProbe.marks.contains { $0.name == HaloProbe.previewBeforeMouseUp && $0.series == HaloProbe.viewerDrag },
                "the viewer drag marked no preview-before-mouse-up: \(dragProbe.marks)")
            let (playback, playbackProbe) = try await Self.playOneSecond()
            expectBodies(playback, atMost: Self.playbackBodies, target: 24)
            let frames = playbackProbe.drawn[HaloProbe.playback]?.count ?? 0
            #expect(frames >= 12, "one second of playback drew \(frames) playback frames into the probe")
            #endif
        }

        @Test(.timeLimit(.minutes(6)), .disabled("report-only: waits on the supervisor listing it in Tests/perf-suites.txt"))
        func timing() async throws {
            #if DEBUG
            let (drag, _) = try await Self.drag()
            let (playback, _) = try await Self.playOneSecond()
            // RenderBudgetHaloTests' bounds: recording must not slow a step.
            expectP95(drag, atMost: 4, target: 8.3)
            expectP95(playback, atMost: 27, target: 8.3)
            #endif
        }

        #if DEBUG
        /// Drags Floor 120 samples across the viewer of the probed `keyed` window.
        static func drag() async throws -> (RenderStep, SuiteFrameProbe) {
            let seen = SeenProbe()
            let project = HaloLaunch(arguments: ["Halo", "-HaloSample", "keyed"]).project()
            let w = RenderBudgetWindow(probed(HaloWindow(model: project).environment(\.haloViewerTakesActivationClicks, true), seen))
            defer { w.close() }
            try await w.settle(500)
            let recorder = try #require(seen.recorder, "the probed window gave no suiteProbeRecorder")
            // Composition (960, 980) is the middle of Floor's band, under nothing else at frame 0.
            let canvas = try #require(await w.element("halo.viewer.canvas"), "no halo.viewer.canvas")
            let start = w.point(CGPoint(x: 960, y: 980), on: CGSize(width: 1920, height: 1080), in: canvas)
            let step = try await w.measure(
                "halo viewer drag, \(dragSamples) samples, probe on", bodies: HaloWindowPlaybackTests.windowBodies
            ) {
                try await w.drag(from: start, by: CGVector(dx: 120, dy: 30), samples: dragSamples)
            }
            return (step, recorder.probe)
        }

        /// One second of 120 Hz refreshes on the playing, probed `keyed` window.
        static func playOneSecond() async throws -> (RenderStep, SuiteFrameProbe) {
            let seen = SeenProbe()
            var project = HaloLaunch(arguments: ["Halo", "-HaloSample", "keyed"]).project()
            let start = 5000.0
            project.play(at: start)
            var links: [HaloFakeLink] = []
            let window = HaloWindow(model: project).environment(\.haloRefreshLink) { receive in
                let link = HaloFakeLink(receive)
                links.append(link)
                return link
            }
            let w = RenderBudgetWindow(probed(window, seen))
            defer { w.close() }
            for _ in 0..<200 where links.isEmpty { try await Task.sleep(for: .milliseconds(20)) }
            let link = try #require(links.last, "the transport never started its driver")
            try await w.settle()
            let recorder = try #require(seen.recorder, "the probed window gave no suiteProbeRecorder")
            let step = try await w.measure("halo playback, 1 s at 120 Hz, probe on", bodies: HaloWindowPlaybackTests.windowBodies) {
                try await w.ticks(120) { link.fire(start + Double($0) / 120) }
            }
            return (step, recorder.probe)
        }

        /// `view` under `-SuitePerfProbe`, with a hidden reader that hands over the window's recorder.
        static func probed(_ view: some View, _ seen: SeenProbe) -> some View {
            view.background { ProbeReader(seen: seen) }.suiteProbes(arguments: ["Halo", SuiteFrameProbe.launchFlag])
        }
        #endif
    }
}

/// The recorder the probed window's reader saw.
@MainActor final class SeenProbe {
    var recorder: SuiteProbeRecorder?
}

/// Reads the window's recorder from the environment once it appears.
private struct ProbeReader: View {
    let seen: SeenProbe
    @Environment(\.suiteProbeRecorder) private var recorder

    var body: some View {
        Color.clear.onAppear { seen.recorder = recorder }
    }
}
#endif
