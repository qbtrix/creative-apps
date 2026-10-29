// RenderBudgetPhotoAreaDragTests.swift: the area tools' drags on the real Photo window (area-selection AR-11),
// hosted like RenderBudgetPhotoFacetsTests (its `host` and `settle`) with the `large` fixture (three 4000 x 3000
// layers). A 120-sample circular Lasso drag sent through the window's intent hook runs PhotoEditor's body at most 3
// times (the packet's "≤ 3 window bodies"; render-contract rule 3) and selects one lasso at the release: the outline
// in progress draws on the canvas overlay without republishing the window's facets. The p95 (≤ 8 ms) is printed,
// not gated. Debug builds only (the tally and the renderer registry exist only there). macOS only.
#if canImport(AppKit) && DEBUG
import AppKit
import PhotoModel
import SwiftUI
import Testing

@testable import PhotoApp
@testable import SuiteUI

@MainActor @Suite(.serialized) struct RenderBudgetPhotoAreaDragTests {
    static let samples = 120

    @Test(.timeLimit(.minutes(3))) func lassoDragRunsTheEditorAtMostThreeTimes() async throws {
        let session = PhotoSession(try PhotoWorkspace.fixture(.large))
        let (w, tally, canvas, send) = try await RenderBudgetPhotoFacetsTests.host(session)
        defer { w.close() }
        send(.tool(.lasso))
        try await RenderBudgetPhotoFacetsTests.settle(w, tally, canvas)
        let center = CGPoint(x: 2000, y: 1500)
        let point = { (i: Int) in
            let a = Double(i) / Double(Self.samples) * 2 * Double.pi
            return CGPoint(x: center.x + 800 * cos(a), y: center.y + 800 * sin(a))
        }
        let step = try await w.measure("photo lasso drag, \(Self.samples) samples, large",
                                       bodies: RenderBudgetPhotoFacetsTests.editor(tally)) {
            try await w.ticks(Self.samples) { send(.drag(point(0), point($0))) }
            send(.endDrag)
        }
        print("RENDER-BUDGET photo lasso drag p95 \(String(format: "%.2f", step.p95)) ms (budget 8, print-only)")
        #expect(session.workspace.undoActionName == "Undo Lasso Select", "the release selects the lasso")
        expectBodies(step, atMost: 3, target: 2)
    }
}
#endif
