// RenderBudgetHaloFileDropTests.swift (file-flow HF-5): what a file drag over the Halo window costs
// (packet Quality tests, "render: a drag hovering over the window, 120 moves"), through the harness
// (RenderBudgetHarness.swift), with Spot open. A real drag session can't run in a test process, and the
// viewer's drop modifier keeps its hover as private state, so the window is wrapped in the same modifier
// (SuiteFileDropModifier) on a hover the test drives the way the drop delegate does (SF-4's
// `SuiteDropHover`, as RenderBudgetFlareFileDropTests): a Promo.halo enters and is planned ("Open in Halo"),
// 120 pointer moves cross the viewer, the file leaves. The window body may run at most twice (the mark's
// arrival and exit), since the mark is an overlay of its own. Nested in BodyCountSuites, as every suite
// that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import HaloModel
import SuiteKernel
import SuiteModel
import SwiftUI
import Testing

@testable import HaloApp
@testable import SuiteShell

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetHaloFileDropTests {
        /// render: a drag hovering over the window, 120 moves ≤ 2 window bodies (gate), target 0.
        static let hoverBodies = 2

        @Test(.timeLimit(.minutes(2))) func dragHoverInTwoBodies() async throws {
            let hover = SuiteDropHover()
            let window = HaloWindow(model: try HaloFileFlowSnapshots.spot())
                .modifier(SuiteFileDropModifier(app: .halo, documentName: "Spot.halo", plan: { _ in [] },
                                                perform: { _ in }, hover: hover))
            let w = RenderBudgetWindow(window)
            defer { w.close() }
            try await w.settle(500)
            // The first frames and the viewer's fit aren't the hover's cost.
            try await w.settle(untilStable: HaloWindowPlaybackTests.windowBodies, turns: 8)
            let promo: [DropAction] = [.open(path: "/tmp/RenderBudgetHaloFileDrop/Promo.halo")]
            let step = try await w.measure("halo file drag hover, mark, 120 moves, leave",
                                           bodies: HaloWindowPlaybackTests.windowBodies) {
                try await w.ticks(1) { _ in hover.planned(promo, for: hover.begin()) }
                #expect(await w.element(SuiteFileControlID.dropMark) != nil, "the hover shows no mark")
                #expect(w.label(SuiteFileControlID.dropMark) == "Open in Halo", "the hover shows no Open in Halo mark")
                try await w.ticks(120) { i in w.send(.mouseMoved, at: CGPoint(x: 300 + 5 * i, y: 360)) }
                try await w.ticks(1) { _ in hover.exit() }
            }
            #expect(w.label(SuiteFileControlID.dropMark) == nil, "the mark stayed after the file left")
            // The mark is an overlay: the window renders at most for its arrival and exit. Target: 0.
            expectBodies(step, atMost: Self.hoverBodies, target: 0)
        }
    }
}
#endif
