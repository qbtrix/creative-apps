// RenderBudgetDesignHeroTests.swift: the one-document hero's edit-while-animated budgets (OD-15 rows 2 and 3,
// Tests/render-budgets.md), on `animated(500)` in the real window. `dragKeyed` scrubs to frame 60, then drags the
// first rectangle where it shows there, 120 samples: gated at Design's drag row, 3 window bodies. `scrubRuler`
// runs 120 ruler scrub steps, each laid out and displayed: gated at 0 window bodies (the canvas alone follows the
// frame). Step times are printed as `BUDGET` lines and not gated here: timing gates belong to the perf list, which
// only the supervisor edits. macOS only.
#if canImport(AppKit)
import AppKit
import DesignModel
import SwiftUI
import Testing
@testable import DesignApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetDesignHeroTests {
        static func bodies() -> Int? {
            #if DEBUG
            return DesignWindow.bodyRuns
            #else
            return nil
            #endif
        }

        @Test(.timeLimit(.minutes(2))) func dragKeyed() async throws {
            #if DEBUG
            let seed = DesignFixtures.animated(500)
            let w = RenderBudgetWindow(DesignWindow(seed: seed, live: DesignLiveDrag()))
            defer { w.close() }
            try await w.settle(800)
            let perform = try #require(DesignWindow.lastPerform, "the window never started")
            perform(.scrub(60))
            try await w.settle(400)  // past the scrub's 0.15 s settle, so frame 60 is the playhead
            try await w.settle(untilStable: Self.bodies)
            let shown = try #require(seed.selectedPage?.sampled(at: 60).nodes.node("node-2")?.frame)
            let board = try #require(await w.element("suite.canvas.artboard"), "no artboard")
            let page = CGSize(width: 1440, height: 1024)
            let start = w.point(CGPoint(x: shown.x + shown.width / 2, y: shown.y + shown.height / 2), on: page, in: board)
            let move = try await w.measure("design drag a keyed shape at frame 60", bodies: Self.bodies) {
                try await w.drag(from: start, by: CGVector(dx: 160, dy: -90))
            }
            print("BUDGET design drag keyed at 60 on animated(500): \(move)")
            #expect((move.bodies ?? 1) >= 1, "the drag never reached the canvas: \(move)")
            expectBodies(move, atMost: 3, target: 3)
            perform(.pause)  // nothing plays: it only records the window's workspace
            let after = try #require(DesignWindow.lastWorkspace)
            #expect(after.playhead == 60, "the drag moved the playhead")
            #expect(after.findNode("node-2")?.time?.tracks[.x]?.contains { $0.frame == 60 } == true,
                    "a drag at frame 60 wrote no x key there")
            #endif
        }

        @Test(.timeLimit(.minutes(2))) func scrubRuler() async throws {
            #if DEBUG
            let seed = DesignFixtures.animated(500)
            let w = RenderBudgetWindow(DesignWindow(seed: seed, live: DesignLiveDrag()))
            defer { w.close() }
            try await w.settle(800)
            try await w.settle(untilStable: Self.bodies)
            let perform = try #require(DesignWindow.lastPerform, "the window never started")
            perform(.pause)
            let pre = try #require(DesignWindow.lastWorkspace)
            let before = DesignWindow.bodyRuns
            var times: [Double] = []
            let clock = ContinuousClock()
            for frame in 1...120 {
                let began = clock.now
                perform(.scrub(frame)); w.host.layoutSubtreeIfNeeded(); w.window.displayIfNeeded()
                times.append(Double((clock.now - began) / .microseconds(1)) / 1000)
            }
            let ran = DesignWindow.bodyRuns - before
            let sorted = times.sorted()
            print(String(format: "BUDGET design scrub ruler 120 steps on animated(500): p50 %.2f p95 %.2f max %.2f ms | over 8.3 ms %d | window bodies %d",
                         sorted[60], sorted[114], sorted.last ?? 0, times.filter { $0 > 8.33 }.count, ran))
            #expect(ran == 0, "a scrub step ran the window: \(ran) bodies")
            try await w.settle(400)
            perform(.pause)
            let landed = try #require(DesignWindow.lastWorkspace)
            #expect(landed.playhead == 120)
            #expect(landed.canUndo == pre.canUndo && landed.isDirty == pre.isDirty)
            #endif
        }
    }
}
#endif
