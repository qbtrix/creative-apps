// RenderBudgetDesignAnimateTests.swift: Design's playback budget (one-document OD-11). `playback` plays
// `animated(500)` and `animated(50)` for 5 s of 120 Hz refreshes on a link the test fires by hand (`designRefreshLink`), each
// refresh timed with the layout and display it forces. Gated: 0 window bodies per frame (the window may run for
// play and pause only), at most PlaybackBudget.ciMaxDroppedFrames (QB-L4) refreshes over 16.7 ms, and no
// document frame skipped between refreshes; pausing lands the frame on screen as the playhead, with no undo step
// and no unsaved change. `playLongForSample` (OD-16) loops `animated(500)` for 24 s so `sample` can catch the
// playback's call tree; it checks nothing and runs only with DESIGN_PLAY_LONG=1 set, on a release build
// (`-c release -Xswiftc -enable-testing -Xswiftc -DDEBUG`). macOS only.
#if canImport(AppKit)
import AppKit
import DesignModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing
@testable import DesignApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetDesignAnimateTests {
        static func bodies() -> Int? {
            #if DEBUG
            return DesignWindow.bodyRuns
            #else
            return nil
            #endif
        }

        @Test(.timeLimit(.minutes(3)), arguments: [500, 50]) func playback(nodes: Int) async throws {
            let live = DesignLiveDrag()
            var links: [HaloFakeLink] = []
            let seed = DesignFixtures.animated(nodes)
            let w = RenderBudgetWindow(DesignWindow(seed: seed, live: live).environment(\.designRefreshLink) { receive in
                let link = HaloFakeLink(receive)
                links.append(link)
                return link
            })
            defer { w.close() }
            try await w.settle(800)
            try await w.settle(untilStable: Self.bodies)
            #if DEBUG
            let perform = try #require(DesignWindow.lastPerform, "the window never started")
            perform(.play)
            let link = try #require(links.last, "play never started the driver")
            let start = 5000.0, refreshes = Int(PlaybackBudget.seconds * 120)
            link.fire(start)
            let before = Self.bodies()
            var whilePlaying = before
            var times: [Double] = [], frames: [Int] = []
            let clock = ContinuousClock()
            for i in 1...refreshes {
                // Counted up to the refresh that ends play once: landing the last frame runs the window once.
                whilePlaying = Self.bodies()
                let began = clock.now
                link.fire(start + Double(i) / 120)
                w.host.layoutSubtreeIfNeeded()
                w.window.displayIfNeeded()
                times.append(Double((clock.now - began) / .microseconds(1)) / 1000)
                guard let frame = live.playingFrame else { break }
                frames.append(frame)
                if i % 30 == 0 { try await Task.sleep(for: .milliseconds(1)) }
            }
            let ran = whilePlaying.flatMap { a in before.map { a - $0 } }
            let sorted = times.sorted()
            let late = times.filter { $0 > 16.7 }.count
            print(String(format: "BUDGET design playback animated(%d): %d refreshes | p50 %.2f p95 %.2f max %.2f ms | over 8.3 ms %d | over 16.7 ms %d | window bodies %@ | late refreshes %@",
                         nodes, times.count, sorted[times.count / 2], sorted[Int(Double(times.count) * 0.95)], sorted.last ?? 0,
                         times.filter { $0 > 8.33 }.count, late, ran.map(String.init) ?? "n/a",
                         times.indices.filter { times[$0] > 16.7 }.map { "\($0 + 1)" }.joined(separator: ",")))
            if let ran { #expect(ran == 0, "a playback tick ran the window: \(ran) bodies") }
            #expect(late <= PlaybackBudget.ciMaxDroppedFrames, "QB-L4: \(late) refreshes over 16.7 ms in 5 s")
            #expect(PlaybackBudget.droppedFrames(in: frames, timelineFrames: seed.time.durationFrames) == 0)
            #expect(frames.first == 0 && live.playingFrame == nil, "play once from the rest pose ran to its end")

            // Play once landed its last frame as the playhead; stop goes back to the rest pose, with no undo step or
            // unsaved change.
            try await w.settle(200)
            perform(.pause)  // nothing plays, so it changes nothing; it records the window's workspace
            #expect(DesignWindow.lastWorkspace?.playhead == seed.time.durationFrames - 1)
            perform(.stop)
            let after = try #require(DesignWindow.lastWorkspace)
            #expect(after.playhead == nil && live.playingFrame == nil)
            #expect(after.isDirty == seed.isDirty && after.canUndo == seed.canUndo)
            #endif
        }

        @Test(.enabled(if: ProcessInfo.processInfo.environment["DESIGN_PLAY_LONG"] == "1"), .timeLimit(.minutes(2)))
        func playLongForSample() async throws {
            let live = DesignLiveDrag()
            live.playLoops = true
            var links: [HaloFakeLink] = []
            let w = RenderBudgetWindow(DesignWindow(seed: DesignFixtures.animated(500), live: live)
                .environment(\.designRefreshLink) { receive in
                    let link = HaloFakeLink(receive)
                    links.append(link)
                    return link
                })
            defer { w.close() }
            try await w.settle(800)
            #if DEBUG
            let perform = try #require(DesignWindow.lastPerform, "the window never started")
            perform(.play)
            let link = try #require(links.last, "play never started the driver")
            let clock = ContinuousClock(), end = clock.now + .seconds(24)
            var i = 0
            while clock.now < end {
                i += 1
                link.fire(5000 + Double(i) / 120)
                w.host.layoutSubtreeIfNeeded()
                w.window.displayIfNeeded()
                if i % 30 == 0 { try await Task.sleep(for: .milliseconds(1)) }
            }
            perform(.stop)
            #endif
        }
    }
}
#endif
