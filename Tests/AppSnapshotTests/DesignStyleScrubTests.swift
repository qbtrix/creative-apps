// DesignStyleScrubTests.swift: what an inspector scrub costs Design's real
// window (style-rows SR-a). A 120-sample drag on the Opacity bar, one on the
// X field and one on the stroke editor's Width row (a 4 pt stroke given first), on `crowd` with its Rectangle 1 (node-2, at 12, 12, 16 × 16; crowd
// has no layer named A) selected: each value previews on the live box
// (DesignLiveDrag), so the window body runs at most 3 times, and mouse-up lands
// one undo step with the copy cleared. The body count is DesignWindow's
// `bodyRuns`, which also covers DesignEditor, built in that body. The test
// process is never the active app, so the root opts in to activation clicks
// (RenderBudgetHarness.swift). It reads DesignWindow statics, so it is nested
// in BodyCountSuites. macOS only.
#if canImport(AppKit)
import AppKit
import DesignModel
import SwiftUI
import Testing

@testable import DesignApp

extension BodyCountSuites {
    @MainActor @Suite struct DesignStyleScrubTests {
        @Test(.timeLimit(.minutes(2))) func opacityScrubRunsTheWindowAtMostThreeTimes() async throws {
            #if DEBUG
            let after = try await Self.scrub(DesignControlID.inspectorOpacity, name: "design scrub opacity") { -Double($0) }
            #expect((after.selectedNode?.opacity ?? 1) < 1)
            #expect(after.undoActionName == "Undo Change Opacity")
            try Self.expectOneStep(after)
            #endif
        }

        @Test(.timeLimit(.minutes(2))) func xFieldScrubRunsTheWindowAtMostThreeTimes() async throws {
            #if DEBUG
            let after = try await Self.scrub(DesignControlID.frameField(.x), name: "design scrub x") { Double($0) }
            #expect((after.selectedNode?.frame.x ?? 0) > 12)
            try Self.expectOneStep(after)
            #endif
        }

        /// The stroke editor's Width scrub lands like the other rows: one step, the live copy cleared.
        @Test(.timeLimit(.minutes(2))) func strokeWidthScrubLandsOneStep() async throws {
            #if DEBUG
            let after = try await Self.scrub("suite.stroke.width", name: "design scrub stroke width", stroke: true) { Double($0) }
            #expect((after.selectedNode?.stroke?.width ?? 0) > 4, "the scrub never landed a wider stroke")
            var undone = after
            undone.undo()
            #expect(undone.selectedNode?.stroke?.width == 4, "one undo left \(String(describing: undone.selectedNode?.stroke))")
            #endif
        }

        #if DEBUG
        /// Drags the control `id` from its middle by `dx(i)` over 120 samples, gates the window's body runs, and
        /// returns the workspace after mouse-up. `stroke` gives the layer a 4 pt stroke first, as its own step.
        static func scrub(_ id: String, name: String, stroke: Bool = false, dx: (Int) -> Double) async throws -> DesignWorkspace {
            var seed = DesignFixtures.crowd
            seed.useServices(.live)
            seed.selectItem("node-2")
            if stroke { try seed.setStyle(.stroke(DesignStroke(color: .black, width: 4))); seed.endEditRun() }
            let live = DesignLiveDrag()
            let w = RenderBudgetWindow(DesignWindow(seed: seed, live: live).allowsWindowActivationEvents())
            defer { w.close() }
            try await w.settle(800)
            let box = try #require(await w.element(id), "no \(id)")
            let start = CGPoint(x: box.midX, y: box.midY)
            DesignWindow.lastWorkspace = nil
            let step = try await w.measure(name, bodies: { DesignWindow.bodyRuns }) {
                try await w.drag(from: start) { CGPoint(x: start.x + dx($0), y: start.y) }
            }
            expectBodies(step, atMost: 3, target: 3)
            #expect(live.workspace == nil, "the live copy outlived the scrub")
            return try #require(DesignWindow.lastWorkspace, "the scrub never reached the window")
        }

        /// The scrub is one undo step: undoing it leaves nothing to undo.
        static func expectOneStep(_ after: DesignWorkspace) throws {
            var after = after
            #expect(after.canUndo)
            after.undo()
            #expect(!after.canUndo)
        }
        #endif
    }
}
#endif
