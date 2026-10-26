// RenderBudgetPhotoPenAnchorTests.swift (#5145): what a Command-drag of a Pen path's anchor costs the real Photo
// window, on the render budget harness (RenderBudgetHarness.swift). It hosts PhotoWindow on the `large` fixture
// (4000 x 3000, 12 MP) with the Pen picked and a closed three-point path in edit, its first anchor picked, puts the
// overlay in point editing (as Command does; `photoPenEditsPoints`) and drags that anchor 120 samples at 120 Hz from
// its overlay mark (`suite.path.anchor-0-0`). The overlay holds the press on its PathLiveDrag until release, so PhotoEditor's body
// (a debug-only counter) runs at most 3 times, for the release's one `path.anchor-move` step. Nested in
// BodyCountSuites, as every suite that reads a body counter is. macOS only.
#if canImport(AppKit)
import AppKit
import PhotoModel
import SuiteKernel
import SwiftUI
import Testing

@testable import PhotoApp

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetPhotoPenAnchorTests {
        @Test(.timeLimit(.minutes(2))) func anchorDragInThreeBodies() async throws {
            var open = try PhotoWorkspace.fixture(.large)
            open.selectTool(.pen)
            for (x, y) in [(1000.0, 1000.0), (3000.0, 1000.0), (2000.0, 2200.0)] { open.runPath(.penAdd(Point(x: x, y: y), handleOut: nil)) }
            open.runPath(.close)
            open.runPath(.select(anchors: [AnchorRef(contour: 0, index: 0)], rect: nil, extend: false))
            let before = try #require(open.pathInEdit?.path, "the Pen left no path in edit: \(open.statusMessage ?? "")")
            // A scripted flagsChanged event doesn't reach onModifierKeysChanged, so the overlay is told to edit points.
            let w = RenderBudgetWindow(PhotoWindow(model: open).environment(\.photoPenEditsPoints, true))
            defer { w.close() }
            let edited = try #require(await w.first(PhotoWindowEditedView.self))
            let bodies = { () -> Int? in BodyCountSuites.PhotoWindowStrokeTests.editorBodies() }
            try await w.settle(untilStable: bodies)
            let mark = try #require(await w.element("suite.path.anchor-0-0"), "the overlay shows no anchor-0-0")
            let drag = try await w.measure("photo pen anchor drag, 120 samples", bodies: bodies) {
                try await w.drag(from: CGPoint(x: mark.midX, y: mark.midY), by: CGVector(dx: 60, dy: 30))
            }
            try await w.settle()
            let after = try #require(edited.workspace?.pathInEdit?.path, "the drag left no path in edit: \(drag)")
            #expect(after.contours.first?.anchors.count == 3, "the press removed the anchor instead of moving it: \(after)")
            #expect(after.contours.first?.anchors.first?.point != before.contours.first?.anchors.first?.point,
                    "the anchor drag left the path as it was: \(drag)")
            #expect(edited.workspace?.undoActionName == "Undo Move Points")
            // The anchor moves on the overlay's copy; the window runs for the release's one step. Target 1.
            expectBodies(drag, atMost: 3, target: 1)
        }
    }
}
#endif
