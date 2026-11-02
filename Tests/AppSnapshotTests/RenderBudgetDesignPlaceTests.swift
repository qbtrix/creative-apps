// RenderBudgetDesignPlaceTests.swift (placed-images PD-u, PD-3 and PD-4): what a picture costs Design's real
// window. `crowd` opened with Frame 1 (node-1) showing a 4000 × 3000 photo (DesignPlaceSeed) and selected. A
// 120-sample drag of its bottom-right handle resizes it on the window's live box, the picture still drawn by
// cover each frame, and lands at mouse-up: at least one window body (a drag that changed nothing fails) and at
// most 3. The ⌥-drag that pans the focus waits: the harness sends its samples without ⌥, and PD-5 builds
// `place.focus`. Nested in BodyCountSuites, as every suite that reads a body counter is. macOS debug builds only.
#if canImport(AppKit) && DEBUG
import AppKit
import SwiftUI
import Testing

@testable import DesignApp
@testable import DesignModel

extension BodyCountSuites {
    @MainActor @Suite struct RenderBudgetDesignPlaceTests {
        /// `crowd` with Frame 1 showing a 4000 × 3000 photo, selected.
        static func seed() throws -> DesignWorkspace {
            let photo = try DesignPlaceSeed.photo(width: 4000, height: 3000)
            var model = DesignFixtures.crowd
            model.useServices(.live)
            model.load(model.pages.map { page in
                var page = page
                page.nodes = page.nodes.map { node in
                    var node = node
                    if node.id == "node-1" { node.placedAsset = photo }
                    return node
                }
                return page
            })
            model.selectItem("node-1")
            return model
        }

        @Test(.timeLimit(.minutes(2))) func resizeCoveredInThreeBodies() async throws {
            let model = try Self.seed()
            #expect(model.selectedNode?.placedImage != nil)
            let w = RenderBudgetWindow(DesignWindow(seed: model, live: DesignLiveDrag()).allowsWindowActivationEvents())
            defer { w.close() }
            try await w.settle(800)
            let board = try #require(await w.element("suite.canvas"), "no canvas")
            let page = DesignWindowDragTests.page
            let start = w.point(CGPoint(x: 170, y: 160), on: page, in: board)
            let end = w.point(CGPoint(x: 290, y: 240), on: page, in: board)
            let step = try await w.measure("design covered picture resize, 120 samples", bodies: DesignWindowDragTests.editorBodies) {
                try await w.drag(from: start, by: CGVector(dx: end.x - start.x, dy: end.y - start.y), samples: 120)
            }
            #expect((step.bodies ?? 0) >= 1, "the resize landed no edit")
            expectBodies(step, atMost: 3, target: 3)
        }

        @Test(.disabled("waits on PD-5's place.focus; the harness sends its samples without ⌥"))
        func focusDragInThreeBodies() async throws {}
    }
}
#endif
