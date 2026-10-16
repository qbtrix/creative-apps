// HaloWindowPlaybackTests.swift: what playback costs the real Halo window
// (#1296). It hosts HaloWindow itself on `-HaloSample keyed` (24 fps, live
// services), already playing, in a 1280 x 820 borderless window ordered in
// far off every screen, as PhotoWindowStrokeTests hosts PhotoWindow, with the
// transport's driver on a HaloFakeLink (the `haloRefreshLink` environment
// value), since the headless CI runner can't serve a real display link. It
// fires one second of 120 Hz refresh targets, a run-loop turn apart so SwiftUI
// can update after each, and counts body runs (debug-only counters). Spec:
// HaloWindow's body runs about once per frame shown, at least 12 times (so
// playback really ran) and at most 24 + 6, not once per refresh. With Ball
// selected, no timeline lane is rebuilt (neither lane's keys change), and a
// TRANSFORM row runs only while its value or key state changes: at most its
// two animated rows (x, opacity), in both of the inspector's layouts, per
// frame. NSHostingView's layout passes are reported, not judged.
// HALO_WINDOW_PLAYBACK_SECONDS=20 first plays that long at 120 Hz, for
// `sample`. macOS only.
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
            let played = try await playOneSecond(selecting: nil)
            print(played.report)
            if let runs = played.window {
                #expect(runs >= played.fps / 2, "the window barely updated while playing: \(played.report)")
                #expect(runs <= played.fps + 6, "the window ran once per refresh, not once per frame: \(played.report)")
            }
        }

        @Test(.timeLimit(.minutes(3))) func playbackRebuildsOnlyTheLanesAndRowsThatChange() async throws {
            let played = try await playOneSecond(selecting: "comp-1-layer-2")
            print(played.report)
            if let runs = played.window { #expect(runs >= played.fps / 2, "the window barely updated: \(played.report)") }
            if let lanes = played.lanes { #expect(lanes == 0, "a lane whose keys didn't change was rebuilt: \(played.report)") }
            if let rows = played.rows {
                #expect(rows <= 2 * 2 * played.fps, "unchanged TRANSFORM rows ran per frame: \(played.report)")
            }
        }

        /// One second of 120 Hz refreshes on the keyed sample, `selecting` that
        /// layer first: the body runs it cost (nil in release) and a report.
        private func playOneSecond(
            selecting layer: String?
        ) async throws -> (fps: Int, window: Int?, lanes: Int?, rows: Int?, report: String) {
            var project = HaloLaunch(arguments: ["Halo", "-HaloSample", "keyed"]).project()
            let fps = try #require(project.selectedComposition?.framesPerSecond)
            if let layer { project.selectLayer(layer) }
            let start = 5000.0
            project.play(at: start)
            var links: [HaloFakeLink] = []
            let window = HaloWindow(model: project).environment(\.haloRefreshLink) { receive in
                let link = HaloFakeLink(receive)
                links.append(link)
                return link
            }
            let host = CountingHostingView(rootView: window)
            let frame = CGRect(x: 0, y: 0, width: 1280, height: 820)
            host.frame = frame
            let shown = NSWindow(contentRect: frame, styleMask: [.borderless], backing: .buffered, defer: false)
            shown.isReleasedWhenClosed = false
            shown.contentView = host
            shown.setFrameOrigin(NSPoint(x: -20_000, y: -20_000))
            shown.orderFrontRegardless()
            defer { shown.close() }

            // The transport starts its driver once it sees the project playing.
            for _ in 0..<200 where links.isEmpty { try await Task.sleep(for: .milliseconds(20)) }
            let link = try #require(links.last, "the transport never started its driver")
            try await Task.sleep(for: .milliseconds(300))

            // Warm-up for `sample`, ending on a whole second so the measured one starts at frame 0.
            let seconds = Double(ProcessInfo.processInfo.environment["HALO_WINDOW_PLAYBACK_SECONDS"] ?? "") ?? 0
            let refreshes = Int(seconds.rounded()) * 120
            if refreshes > 0 { try await play(link, from: start, refreshes: refreshes) }
            let measuredStart = start + Double(refreshes) / 120

            let before = bodies()
            let layouts = host.layouts
            let layoutTime = host.layoutTime
            try await play(link, from: measuredStart, refreshes: 120)
            try await Task.sleep(for: .milliseconds(100))
            let after = bodies()
            let runs = after.map { a in before.map { b in (a.window - b.window, a.lanes - b.lanes, a.rows - b.rows) } } ?? nil
            let passes = host.layouts - layouts
            let passTime = host.layoutTime - layoutTime

            let counts = runs.map { "window bodies \($0.0), lanes \($0.1), TRANSFORM rows \($0.2)" } ?? "bodies n/a"
            let report = [
                "WINDOW-PLAYBACK sample=keyed fps=\(fps) selected=\(layer ?? "none") window=1280x820 refreshes=120@120Hz |",
                "\(counts), SwiftUI passes \(passes) (\(String(format: "%.1f", passTime)) ms)",
            ].joined(separator: " ")
            return (fps, runs?.0, runs?.1, runs?.2, report)
        }

        /// The window's, the lanes' and the TRANSFORM rows' body runs so far;
        /// nil in release, which has no counters.
        private func bodies() -> (window: Int, lanes: Int, rows: Int)? {
            #if DEBUG
            return (HaloWindow.bodyRuns, TimelineLane<String>.bodyRuns, HaloPropertyRowView.bodyRuns)
            #else
            return nil
            #endif
        }

        /// `refreshes` targets 1/120 s apart after `from`, one per real 1/120 s.
        private func play(_ link: HaloFakeLink, from: Double, refreshes: Int) async throws {
            let clock = ContinuousClock()
            let began = clock.now
            for i in 1...refreshes {
                try await Task.sleep(until: began + .microseconds(8_333 * i), clock: clock)
                link.fire(from + Double(i) / 120)
            }
        }
    }
}
#endif
