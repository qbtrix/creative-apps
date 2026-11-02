// RenderBudgetPhotoFacetsTests.swift: the AppKit window shell plan's slice 1
// (facets) on the real Photo window, hosted on the render budget harness
// (RenderBudgetHarness.swift) with the `large` fixture (three 4000 x 3000
// layers). The window keeps its PhotoWorkspace in a PhotoSession that
// republishes it as facets, and each view re-runs only for the facets it reads:
// - 30 Brush size steps run PhotoEditor's body 0 times and PhotoPanel's 30
//   times, call the canvas view's `show` 0 times, and the Size row then shows
//   the last size.
// - A layer click (`pickLayer`) calls the canvas view's `show` 0 times and runs
//   PhotoPanel's body at most once, and the Layer section then shows the
//   picked layer's opacity.
// Bodies are counted on the window's own SuiteUI BodyTally and `show` calls on
// its own CanvasHostView, never a process-wide static (factory lesson 345), so
// the suite needs no BodyCountSuites nesting. Intents go through the window's
// intent hook (PhotoWindowEditedView.send), the path the panel's rows and the
// layer list send, never an accessibility press or real input (lessons 344,
// 346). The p95s (plan: ≤ 8 ms) are printed, not gated: a step-time budget
// belongs in a Tests/perf-suites.txt test, which only the supervisor lists.
// Debug builds only: the tally, `showCalls` and the renderer registry exist only there. macOS only.
#if canImport(AppKit) && DEBUG
import AppKit
import PhotoModel
import SwiftUI
import Testing

@testable import PhotoApp
@testable import SuiteUI

@MainActor @Suite(.serialized) struct RenderBudgetPhotoFacetsTests {
    static let steps = 30

    @Test(.timeLimit(.minutes(3))) func brushSizeStepsRunOnlyThePanel() async throws {
        let session = PhotoSession(try PhotoWorkspace.fixture(.large))
        let (w, tally, canvas, send) = try await Self.host(session)
        defer { w.close() }
        send(.tool(.brush))
        try await Self.settle(w, tally, canvas)
        let start = session.workspace.brushOptions.size
        let sizes = (1...Self.steps).map { start + Double($0) }
        #expect(sizes.allSatisfy(ToolOptions.sizeRange.contains))

        let (panel, shows) = (tally.runs(of: PhotoPanel.self), canvas.showCalls)
        let step = try await w.measure("photo brush size, \(Self.steps) steps, large", bodies: Self.editor(tally)) {
            try await w.ticks(Self.steps) { send(.toolOption(.size(sizes[$0 - 1]))) }
        }
        print("RENDER-BUDGET photo brush size p95 \(String(format: "%.2f", step.p95)) ms (budget 8, print-only)")
        #expect(session.workspace.brushOptions.size == sizes.last)
        #expect(w.value("photo.tool.size")?.contains("\(Int(sizes.last ?? 0))") == true,
                "the Size row shows \(w.value("photo.tool.size") ?? "nothing")")
        #expect(step.bodies == 0, "\(step)")
        #expect(tally.runs(of: PhotoPanel.self) - panel == Self.steps)
        #expect(canvas.showCalls - shows == 0)
    }

    @Test(.timeLimit(.minutes(3))) func layerClickShowsNothingOnTheCanvas() async throws {
        let session = PhotoSession(try PhotoWorkspace.fixture(.large))
        let picked = try #require(session.workspace.layers.map(\.id).first { $0 != session.workspace.selectedLayerID })
        let (w, tally, canvas, send) = try await Self.host(session)
        defer { w.close() }
        send(.opacity(picked, 40))
        try await Self.settle(w, tally, canvas)

        let (panel, shows) = (tally.runs(of: PhotoPanel.self), canvas.showCalls)
        let step = try await w.measure("photo layer click, large", bodies: Self.editor(tally)) {
            try await w.ticks(1) { _ in send(.pickLayer(picked, .replace)) }
        }
        print("RENDER-BUDGET photo layer click p95 \(String(format: "%.2f", step.p95)) ms (print-only)")
        #expect(session.workspace.selectedLayerIDs == [picked])
        #expect(w.value("photo.layer.opacity")?.contains("40") == true,
                "the Layer section shows \(w.value("photo.layer.opacity") ?? "nothing")")
        #expect(tally.runs(of: PhotoPanel.self) - panel <= 1)
        #expect(canvas.showCalls - shows == 0)
    }

    /// The window on `session` with its own tally, its canvas view and its intent hook, settled.
    static func host(_ session: PhotoSession) async throws -> (
        RenderBudgetWindow<some View>, BodyTally, CanvasHostView, PhotoPerform
    ) {
        let tally = BodyTally()
        let w = RenderBudgetWindow(PhotoWindow(session: session).environment(\.bodyTally, tally))
        let edited = try #require(await w.first(PhotoWindowEditedView.self))
        let send = try #require(edited.send)
        let canvas = try #require(await w.first(CanvasHostView.self))
        try await settle(w, tally, canvas)
        return (w, tally, canvas, send)
    }

    /// Waits for the window's bodies to stop and its renderer to finish the picture, so no first-render tile
    /// lands inside a measurement.
    static func settle(_ w: RenderBudgetWindow<some View>, _ tally: BodyTally, _ canvas: CanvasHostView) async throws {
        try await w.settle(untilStable: editor(tally))
        for _ in 0..<500 {
            if CanvasRenderer.rendering(into: canvas)?.isSettled ?? true { break }
            try await w.settle(20)
        }
        try await w.settle(untilStable: editor(tally))
    }

    /// The window's editor body runs.
    static func editor(_ tally: BodyTally) -> () -> Int? { { tally.runs(of: PhotoEditor.self) } }
}
#endif
