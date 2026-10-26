// RenderBudgetFlareAnchorTests.swift (pen-paths FP-3, slice FP-u): an anchor drag's render budget
// (Tests/render-budgets.md) on the real window, through the harness (RenderBudgetHarness.swift). On `bounce`, Direct
// Select picks Ball and its first anchor, then drags that anchor 120 samples from its overlay mark
// (`suite.path.anchor-0-0`): the samples run on the stage's FlareLiveDrag, whose copy the path overlay reads, so the
// window's body runs only for the drag's end at mouse-up. `anchorDragInThreeBodies` gates the window-body count;
// `timing` judges the step times against the packet's 8 ms and is report-only: it stays disabled until
// Tests/perf-suites.txt lists it (only the supervisor edits that list). Nested in BodyCountSuites. macOS only.
#if canImport(AppKit)
import AppKit
import FlareCore
import FlareModel
import SuiteKernel
import SwiftUI
import Testing

@testable import FlareApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetFlareAnchorTests {
        @Test(.timeLimit(.minutes(2))) func anchorDragInThreeBodies() async throws {
            let drag = try await Self.run()
            // The anchor moves on the stage's live copy; the window runs for the drag's end at most. Target: 3.
            expectBodies(drag, atMost: 3, target: 3)
        }

        @Test(.disabled("report-only: enable once Tests/perf-suites.txt lists it"), .timeLimit(.minutes(2)))
        func timing() async throws {
            let drag = try await Self.run()
            // Target: a step fits the packet's 8 ms (one 120 Hz frame).
            expectP95(drag, atMost: 20, target: 8)  // not measured yet
        }

        static func run() async throws -> RenderStep {
            var model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
            model.selectTool(.directSelect)
            model.drag(from: Point(x: 80, y: 100), to: Point(x: 80, y: 100))
            model.runPath(.select(anchors: [AnchorRef(contour: 0, index: 0)], rect: nil, extend: false))
            let before = try #require(model.editablePath?.path, "Direct Select on Ball put no path in edit")
            let w = RenderBudgetWindow(FlareWindow(model: model))
            defer { w.close() }
            try await w.settle(500)
            let mark = try #require(await w.element("suite.path.anchor-0-0"), "the overlay shows no anchor-0-0")
            let bodies = { () -> Int? in
                #if DEBUG
                return FlareWindow.bodyRuns
                #else
                return nil
                #endif
            }
            let drag = try await w.measure("flare anchor drag", bodies: bodies) {
                try await w.drag(from: CGPoint(x: mark.midX, y: mark.midY), by: CGVector(dx: 60, dy: 0))
            }
            try await w.settle(100)
            #if DEBUG
            let after = FlareWindow.shownModel?.editablePath?.path
            #expect(after != nil && after != before, "the anchor drag left Ball's path as it was: \(drag)")
            #endif
            return drag
        }
    }
}
#endif
