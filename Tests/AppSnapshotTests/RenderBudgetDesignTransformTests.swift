// RenderBudgetDesignTransformTests.swift (transform DT-4): what turning a layer costs Design's real window.
// `cards` opened with C (node-4, 700 100 100 × 120) turned 30° and selected (DesignTransformSeed), the canvas
// live (DesignLiveDrag). `run` presses where the kernel puts the rotate knob, two handle sizes above C's top
// middle (BoxMath.handles) turned with C, and drags it 120 samples a quarter circle round C's centre, then
// drags the inspector's Rotation bar (`design.inspector.rotation`) 120 samples. `bodies` gates that each runs
// the window body at most 3 times; `timing` (Tests/perf-suites.txt, report-only) judges p95 within 8 ms.
// Both gestures turn C on the window's live copy (DesignLiveDrag) and land once at the end, so the samples
// redraw the canvas and the inspector, not the window. The window settles until its bodies stop running
// before each drag starts. The test process is never the active app, so the root opts in to activation
// clicks. Nested in BodyCountSuites, as every suite that reads a body counter is. macOS debug builds only:
// the body counters exist only there.
#if canImport(AppKit) && DEBUG
import AppKit
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetDesignTransformTests {
        static let page = CGSize(width: 1440, height: 1024)
        static let c = CGRect(x: 700, y: 100, width: 100, height: 120)

        @Test(.timeLimit(.minutes(2))) func bodies() async throws {
            let (knob, scrub) = try await Self.run()
            expectBodies(knob, atMost: 3, target: 3)
            expectBodies(scrub, atMost: 3, target: 3)
        }

        @Test(.timeLimit(.minutes(2))) func timing() async throws {
            let (knob, scrub) = try await Self.run()
            expectP95(knob, atMost: 8, target: 4)
            expectP95(scrub, atMost: 8, target: 4)
        }

        static func run() async throws -> (knob: RenderStep, scrub: RenderStep) {
            let w = Self.window()
            defer { w.close() }
            try await Self.settle(w)
            let board = try #require(await w.element("suite.canvas.artboard"), "no artboard")
            // The knob sits two handle sizes above C's top middle; a handle is one size on screen at any zoom.
            let size = Double(SuiteSize.selectionHandle) * Double(Self.page.width / board.width)
            let centre = CGPoint(x: Self.c.midX, y: Self.c.midY)
            let radius = Double(Self.c.height) / 2 + 2 * size
            // C is turned 30°, so its knob is too: a quarter circle clockwise from there round C's centre,
            // in page points (y down).
            let from = (30 - 90) * Double.pi / 180
            let at = { (i: Int) -> CGPoint in
                let a = from + (Double.pi / 2) * Double(i) / 120
                let p = CGPoint(x: Double(centre.x) + radius * cos(a), y: Double(centre.y) + radius * sin(a))
                return w.point(p, on: Self.page, in: board)
            }
            let knob = try await w.measure("design transform knob drag, 120 samples", bodies: Self.windowBodies) {
                try await w.drag(from: at(0), path: at)
            }
            #expect(knob.steps >= 120, "the drag sent \(knob.steps) steps")
            try await w.settle(untilStable: { DesignWindow.bodyRuns + DesignEditor.bodyRuns })
            let box = try #require(await w.element(DesignControlID.inspectorRotation), "no Rotation bar")
            let start = CGPoint(x: box.midX, y: box.midY)
            let scrub = try await w.measure("design transform rotation scrub, 120 samples", bodies: Self.windowBodies) {
                try await w.drag(from: start) { CGPoint(x: start.x + Double($0), y: start.y) }
            }
            #expect(scrub.steps >= 120, "the scrub sent \(scrub.steps) steps")
            return (knob, scrub)
        }

        /// DesignWindow's body runs, which cover DesignEditor, built in that body.
        static func windowBodies() -> Int? { DesignWindow.bodyRuns }

        /// The window on the turned C with the canvas live.
        static func window() -> RenderBudgetWindow<some View> {
            let seed = DesignTransformSeed.turned
            return RenderBudgetWindow(DesignWindow(seed: seed, live: DesignLiveDrag()).allowsWindowActivationEvents())
        }

        /// Waits for the canvas, then until the window's bodies stop running.
        static func settle<V: View>(_ w: RenderBudgetWindow<V>) async throws {
            try await w.settle(800)
            _ = try #require(await w.element("suite.canvas.artboard"), "no artboard")
            try await w.settle(untilStable: { DesignWindow.bodyRuns + DesignEditor.bodyRuns })
        }
    }
}
#endif
