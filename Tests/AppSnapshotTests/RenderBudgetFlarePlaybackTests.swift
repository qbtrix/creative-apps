// RenderBudgetFlarePlaybackTests.swift: Flare's playback budget, the twin of RenderBudgetDesignAnimateTests. `playback`
// opens a fixture on the built services (as the app launches), plays it and fires 5 s of 120 Hz refreshes on a link
// the test fires by hand (`flareRefreshLink`), each refresh timed with the layout and display it forces. `bounce`
// plays once to its end, `showcase` loops. Gated: 0 window bodies per refresh (the window may run for play and the
// landing only), the frame on screen moves with no document frame skipped, and on an optimized build at most
// PlaybackBudget.ciMaxDroppedFrames (QB-L4) refreshes over 16.7 ms (a debug build prints the timings). Pause, or
// play once ending, lands the frame on screen as the window's playhead, with no undo step and no unsaved change.
// macOS only.
#if canImport(AppKit)
import AppKit
import FlareCore
import FlareModel
@testable import SuiteUI
import SwiftUI
import Testing
@testable import FlareApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetFlarePlaybackTests {
        static func bodies() -> Int? {
            #if DEBUG
            return FlareWindow.bodyRuns
            #else
            return nil
            #endif
        }

        /// An optimized build gates the refresh times; a debug build (the gate, a busy runner) only prints them.
        static let timed = !_isDebugAssertConfiguration()

        @Test(.timeLimit(.minutes(3)), arguments: ["bounce", "showcase"]) func playback(fixture: String) async throws {
            var seed = FlareWorkspace(services: .built)
            seed.finishOpen(.success(try #require(FlareFixtures.named(fixture))), named: "\(fixture).flare")
            let playsOnce = fixture == "bounce"
            var links: [HaloFakeLink] = []
            let w = RenderBudgetWindow(FlareWindow(model: seed).environment(\.flareRefreshLink) { receive in
                let link = HaloFakeLink(receive)
                links.append(link)
                return link
            })
            defer { w.close() }
            try await w.settle(800)
            try await w.settle(untilStable: Self.bodies)
            #if DEBUG
            let perform = try #require(FlareWindow.shownPerform, "the window never started")
            if playsOnce { perform(.timeline(.setLoops(false))) }
            perform(.timeline(.togglePlay))
            try await w.settle(100)
            let link = try #require(links.last, "play never started the driver")
            let start = 5000.0, refreshes = Int(PlaybackBudget.seconds * 120)
            link.fire(start)
            w.host.layoutSubtreeIfNeeded()
            w.window.displayIfNeeded()
            let before = Self.bodies()
            var whilePlaying = before
            var times: [Double] = [], frames: [Int] = []
            let clock = ContinuousClock()
            for i in 1...refreshes {
                // Counted through the refresh that ends play once; its landing runs the window once, a turn later.
                whilePlaying = Self.bodies()
                let began = clock.now
                link.fire(start + Double(i) / 120)
                w.host.layoutSubtreeIfNeeded()
                w.window.displayIfNeeded()
                times.append(Double((clock.now - began) / .microseconds(1)) / 1000)
                let shown = try #require(FlareCanvas.shown, "the canvas never ran")
                frames.append(shown.frame)
                if !shown.playing { break }
                if i % 30 == 0 { try await Task.sleep(for: .milliseconds(1)) }
            }
            let ran = whilePlaying.flatMap { a in before.map { a - $0 } }
            let sorted = times.sorted()
            let late = times.filter { $0 > 16.7 }.count
            print(String(format: "BUDGET flare playback %@: %d refreshes | p50 %.2f p95 %.2f max %.2f ms | over 8.3 ms %d | over 16.7 ms %d | window bodies %@ | frames %d to %d",
                         fixture, times.count, sorted[times.count / 2], sorted[Int(Double(times.count) * 0.95)],
                         sorted.last ?? 0, times.filter { $0 > 8.33 }.count, late, ran.map(String.init) ?? "n/a",
                         frames.first ?? -1, frames.last ?? -1))
            if let ran { #expect(ran == 0, "a playback refresh ran the window: \(ran) bodies in \(times.count) refreshes") }
            if Self.timed { #expect(late <= PlaybackBudget.ciMaxDroppedFrames, "QB-L4: \(late) refreshes over 16.7 ms") }
            let timeline = seed.timelineFrames
            #expect(Set(frames).count > 1, "the frame on screen never moved: \(frames.prefix(10))")
            #expect(PlaybackBudget.droppedFrames(in: frames, timelineFrames: timeline) == 0)
            if playsOnce {
                #expect(frames.last == timeline - 1, "play once never reached its last frame")
            } else {
                perform(.timeline(.togglePlay))  // pause
            }

            // The frame on screen lands as the window's playhead, with no undo step and no unsaved change.
            try await w.settle(200)
            let after = try #require(FlareWindow.shownModel)
            #expect(!after.isPlaying && after.currentFrame == frames.last, "landed \(after.currentFrame), shown \(frames.last ?? -1)")
            #expect(after.isDirty == seed.isDirty && after.canUndo == seed.canUndo)
            #endif
        }
    }
}
#endif
