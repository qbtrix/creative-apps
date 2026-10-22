// RenderBudgetFlareFileDropTests.swift (file-flow FL-5): what a file drag over the Flare window costs
// (Tests/render-budgets.md), through the harness (RenderBudgetHarness.swift), with Bounce open. A real drag
// session can't run in a test process, and the stage's drop modifier keeps its hover as private state, so the
// window is wrapped in the same modifier (SuiteFileDropModifier) on a hover the test drives the way the drop
// delegate does (SF-4's `SuiteDropHover`, as RenderBudgetFileDropTests): a Title.flare enters and is planned
// ("Open in Flare"), 120 pointer moves cross the stage, the file leaves. The window body may run at most
// twice (the mark's arrival and exit), since the mark is an overlay of its own. Nested in BodyCountSuites, as
// every suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import FlareModel
import SuiteKernel
import SuiteModel
import SwiftUI
import Testing

@testable import FlareApp
@testable import SuiteShell

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetFlareFileDropTests {
        @Test(.timeLimit(.minutes(2))) func dragHoverInTwoBodies() async throws {
            let hover = SuiteDropHover()
            let window = FlareWindow(model: try FlareFileFlowSnapshots.bounce())
                .modifier(SuiteFileDropModifier(app: .flare, documentName: "Bounce.flare", plan: { _ in [] },
                                                perform: { _ in }, hover: hover))
            let w = RenderBudgetWindow(window)
            defer { w.close() }
            try await w.settle(500)
            let bodies = { () -> Int? in
                #if DEBUG
                return FlareWindow.bodyRuns
                #else
                return nil
                #endif
            }
            // The first frames and the stage's fit aren't the hover's cost.
            try await w.settle(untilStable: bodies, turns: 8)
            let title: [DropAction] = [.open(path: "/tmp/RenderBudgetFlareFileDrop/Title.flare")]
            let step = try await w.measure("flare file drag hover, mark, 120 moves, leave", bodies: bodies) {
                try await w.ticks(1) { _ in hover.planned(title, for: hover.begin()) }
                #expect(await w.element(SuiteFileControlID.dropMark) != nil, "the hover shows no mark")
                #expect(w.label(SuiteFileControlID.dropMark) == "Open in Flare", "the hover shows no Open in Flare mark")
                try await w.ticks(120) { i in w.send(.mouseMoved, at: CGPoint(x: 300 + 6 * i, y: 420)) }
                try await w.ticks(1) { _ in hover.exit() }
            }
            #expect(w.label(SuiteFileControlID.dropMark) == nil, "the mark stayed after the file left")
            // The mark is an overlay: the window renders at most for its arrival and exit. Target: 0.
            expectBodies(step, atMost: 2, target: 0)
        }
    }
}
#endif
