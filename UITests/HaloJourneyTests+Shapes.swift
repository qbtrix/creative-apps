// HaloJourneyTests+Shapes.swift: J-HS, a star layer drawn by the viewer
// (shape-tools; docs/blueprints/halo/features/shape-tools.md, Journey steps).
// On `-HaloSample three-layers` it clicks the Shape button by the viewer
// (`halo.viewer.shape`), picks Star and types Points 6 in its options
// popover (`suite.shape.chip-star`, `suite.shape.points`), drags in the
// viewer for a new selected "Star" layer, scrubs its Scale X and renders
// frame 0. Written by HS-2 against the stubs and skipped until HS-7 turns it
// on, on live services. One shot per step, `halo-shape-<step>`.
import XCTest

final class HaloShapeJourneyTests: XCTestCase {
    /// J-HS: Shape button, Star with 6 points, a drag draws the layer, Scale X stretches it, frame 0 renders.
    @MainActor func testDrawStarLayer() throws {
        throw XCTSkip("waits on HS-7: the Shape tool draws nothing until HS-5 builds HaloProject's ShapeTarget")
    }
}
