// RenderBudgetDesignEyedropperTests.swift (eyedropper DY-4): the loupe's render budget on the real window.
// `run` opens `cards` with the Eyedropper active and sends 120 pointer samples, one per 1/120 s, from inside A
// across to B through the canvas's own pointer handler (DesignCanvasFeedback.onPointer, the call its continuous
// hover makes). `loupeTrackInThreeBodies` checks that the loupe's body follows the samples while the window's and
// DesignEditor's bodies run 3 times or fewer; `loupeTrackTiming` holds the p95 budget (8 ms) and is report-only
// (perf-suites). The window settles until its bodies stop running before the samples start. Nested in
// BodyCountSuites, as every suite that reads a body counter is. macOS debug builds only: the body counters exist
// only there.
#if canImport(AppKit) && DEBUG
import AppKit
import DesignModel
import SwiftUI
import Testing

@testable import DesignApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetDesignEyedropperTests {
        @Test(.timeLimit(.minutes(2))) func loupeTrackInThreeBodies() async throws {
            let track = try await Self.run()
            #expect(track.point == DesignPoint(x: 350, y: 120))
            #expect(track.loupeRuns >= 60, "the loupe didn't follow the pointer: \(track.step)")
            #expect(track.windowRuns <= 3, "the window body ran on the loupe's samples")
            expectBodies(track.step, atMost: 3, target: 0)
        }

        @Test(.timeLimit(.minutes(2))) func loupeTrackTiming() async throws {
            let track = try await Self.run()
            // Target: a pointer sample fits one 120 Hz frame.
            expectP95(track.step, atMost: 8, target: 4)
        }

        /// The 120 samples' step, where the loupe ended, and how often the loupe's and the window's bodies ran.
        static func run() async throws -> (step: RenderStep, point: DesignPoint, loupeRuns: Int, windowRuns: Int) {
            var seed = DesignFixtures.cards
            seed.useServices(.fake)
            seed.selectTool(.eyedropper)
            let w = RenderBudgetWindow(DesignWindow(seed: seed))
            defer { w.close() }
            try await w.settle(800)
            _ = try #require(await w.element("suite.canvas"), "no canvas")
            try await w.settle(untilStable: { DesignWindow.bodyRuns + DesignEditor.bodyRuns })
            // The same document and page the window shows, so the shared store's loupe is its canvas's.
            let shared = DesignCanvasHover.shared
            defer { shared.record(nil, modifiers: [], on: seed) }
            let handler = try #require(DesignCanvasFeedback(model: seed, zoom: 1).onPointer)
            let windowBefore = DesignWindow.bodyRuns
            let loupeBefore = DesignSampleLoupe.bodyRuns
            // From inside A (100, 100, 100 × 80) across to B and on, a new point every sample.
            let step = try await w.measure(
                "design eyedropper loupe, 120 samples", bodies: DesignWindowDragTests.editorBodies
            ) {
                try await w.ticks(120) { i in handler(CGPoint(x: 110 + Double(i) * 2, y: 120 + Double(i % 40))) }
            }
            let loupe = try #require(shared.loupe(for: seed), "no loupe after the samples")
            return (
                step, loupe.point, DesignSampleLoupe.bodyRuns - loupeBefore, DesignWindow.bodyRuns - windowBefore
            )
        }
    }
}
#endif
