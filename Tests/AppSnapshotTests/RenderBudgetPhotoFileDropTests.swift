// RenderBudgetPhotoFileDropTests.swift (file-flow PF-5): what a file drag over the Photo window costs
// (Tests/render-budgets.md), through the harness (RenderBudgetHarness.swift), on the `large` fixture. A real
// drag session can't run in a test process, so the suite's drop modifier is hosted around the window with a
// hover the test drives the way the modifier's delegate does (SuiteDropHover, SF-4): Logo.png enters and is
// planned ("Place in Sunset.png"), 120 pointer moves cross the canvas, the file leaves. PhotoEditor's body may
// run at most twice (the mark's arrival and exit), since the mark is an overlay of its own. Nested in
// BodyCountSuites, as every suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import PhotoModel
import SuiteKernel
import SwiftUI
import Testing

@testable import PhotoApp
@testable import SuiteShell

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetPhotoFileDropTests {
        @Test(.timeLimit(.minutes(2))) func dragHoverInTwoBodies() async throws {
            let hover = SuiteDropHover()
            let drop = SuiteFileDropModifier(
                app: .photo, documentName: "Sunset.png", plan: { _ in [] }, perform: { _ in }, hover: hover)
            let w = RenderBudgetWindow(PhotoWindow(model: try PhotoWorkspace.fixture(.large)).modifier(drop))
            defer { w.close() }
            let bodies = { () -> Int? in BodyCountSuites.PhotoWindowStrokeTests.editorBodies() }
            // The first picture and its tiles aren't the hover's cost.
            try await w.settle(800)
            try await w.settle(untilStable: bodies, turns: 8)
            let logo: [DropAction] = [.place(path: "/tmp/Logo.png")]
            let step = try await w.measure("photo file drag hover: mark, 120 moves, leave", bodies: bodies) {
                try await w.ticks(1) { _ in hover.planned(logo, for: hover.begin()) }
                #expect(await w.element(SuiteFileControlID.dropMark) != nil, "the hover shows no mark")
                #expect(w.label(SuiteFileControlID.dropMark) == "Place in Sunset.png", "the mark doesn't say Place")
                try await w.ticks(120) { i in w.send(.mouseMoved, at: CGPoint(x: 160 + 8 * i, y: 400)) }
                try await w.ticks(1) { _ in hover.exit() }
            }
            #expect(w.label(SuiteFileControlID.dropMark) == nil, "the mark stayed after the file left")
            // The mark is an overlay: the editor renders at most for its arrival and exit. Target: 0.
            expectBodies(step, atMost: 2, target: 0)
        }
    }
}
#endif
