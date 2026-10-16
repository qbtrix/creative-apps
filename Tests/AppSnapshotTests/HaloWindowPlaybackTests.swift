// HaloWindowPlaybackTests.swift: what playback costs the real Halo window
// (#1296), on the render budget harness (RenderBudgetHarness.swift). It hosts
// HaloWindow itself on `-HaloSample keyed` (24 fps, live services), already
// playing, with the transport's driver on a HaloFakeLink (the
// `haloRefreshLink` environment value), since the headless CI runner can't
// serve a real display link. It fires one second of 120 Hz refresh targets,
// one per real 1/120 s, and counts body runs (debug-only counters). Spec:
// HaloWindow's body runs about once per frame shown, at least 12 times (so
// playback really ran) and at most 24 + 6, not once per refresh. With Ball
// selected, no timeline lane is rebuilt (neither lane's keys change), and a
// TRANSFORM row runs only while its value or key state changes: at most its
// two animated rows (x, opacity), in both of the inspector's layouts, per
// frame. Layout passes and step times are reported; RenderBudgetHaloTests'
// timing test judges them. HALO_WINDOW_PLAYBACK_SECONDS=20 first plays that
// long at 120 Hz, for `sample`. The suite nests in BodyCountSuites: it reads
// process-global body counters. macOS only.
#if canImport(AppKit)
import AppKit
import HaloModel
import SwiftUI
import Testing

@testable import HaloApp
@testable import SuiteUI

extension BodyCountSuites {
    @MainActor @Suite struct HaloWindowPlaybackTests {
        @Test(.timeLimit(.minutes(3))) func playbackRunsTheWindowOncePerFrame() async throws {
            let played = try await Self.playOneSecond()
            if let runs = played.step.bodies {
                #expect(runs >= played.fps / 2, "the window barely updated while playing: \(played.step)")
                #expect(runs <= played.fps + 6, "the window ran once per refresh, not once per frame: \(played.step)")
            }
        }

        @Test(.timeLimit(.minutes(3))) func playbackRebuildsOnlyTheLanesAndRowsThatChange() async throws {
            let played = try await Self.playOneSecond(selecting: "comp-1-layer-2")
            if let runs = played.step.bodies { #expect(runs >= played.fps / 2, "the window barely updated: \(played.step)") }
            if let lanes = played.lanes { #expect(lanes == 0, "a lane whose keys didn't change was rebuilt: \(played.step), lanes \(lanes)") }
            if let rows = played.rows {
                #expect(rows <= 2 * 2 * played.fps, "unchanged TRANSFORM rows ran per frame: \(played.step), rows \(rows)")
            }
        }

        /// One second of 120 Hz refreshes on the playing window, after `warmUp` unmeasured ones (default:
        /// HALO_WINDOW_PLAYBACK_SECONDS), `selecting` that layer first: the step, the composition's frame
        /// rate and the timeline lanes' and TRANSFORM rows' body runs (nil in release).
        static func playOneSecond(
            selecting layer: String? = nil, warmUp: Int? = nil
        ) async throws -> (step: RenderStep, fps: Int, lanes: Int?, rows: Int?) {
            var project = HaloLaunch(arguments: ["Halo", "-HaloSample", "keyed"]).project()
            let fps = try #require(project.selectedComposition?.framesPerSecond)
            if let layer { project.selectLayer(layer) }
            let start = 5000.0
            project.play(at: start)
            var links: [HaloFakeLink] = []
            let w = RenderBudgetWindow(HaloWindow(model: project).environment(\.haloRefreshLink) { receive in
                let link = HaloFakeLink(receive)
                links.append(link)
                return link
            })
            defer { w.close() }

            // The transport starts its driver once it sees the project playing.
            for _ in 0..<200 where links.isEmpty { try await Task.sleep(for: .milliseconds(20)) }
            let link = try #require(links.last, "the transport never started its driver")
            try await w.settle()

            // Warm-up for `sample`, ending on a whole second so the measured one starts at frame 0.
            let seconds = Double(ProcessInfo.processInfo.environment["HALO_WINDOW_PLAYBACK_SECONDS"] ?? "") ?? 0
            let warm = warmUp ?? Int(seconds.rounded()) * 120
            if warm > 0 { try await w.ticks(warm) { link.fire(start + Double($0) / 120) } }
            let measured = start + Double(warm) / 120
            let before = childBodies()
            let step = try await w.measure(
                "halo playback, 1 s at 120 Hz (\(fps) fps), selected \(layer ?? "none")", bodies: windowBodies
            ) {
                try await w.ticks(120) { link.fire(measured + Double($0) / 120) }
            }
            let after = childBodies()
            return (step, fps, after.flatMap { a in before.map { a.lanes - $0.lanes } }, after.flatMap { a in before.map { a.rows - $0.rows } })
        }

        /// HaloWindow's body runs so far; nil in release, which has no counter.
        static func windowBodies() -> Int? {
            #if DEBUG
            return HaloWindow.bodyRuns
            #else
            return nil
            #endif
        }

        /// The timeline lanes' and TRANSFORM rows' body runs so far; nil in release.
        private static func childBodies() -> (lanes: Int, rows: Int)? {
            #if DEBUG
            return (TimelineLane<String>.bodyRuns, HaloPropertyRowView.bodyRuns)
            #else
            return nil
            #endif
        }
    }
}
#endif
