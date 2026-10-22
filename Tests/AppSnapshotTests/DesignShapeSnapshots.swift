// DesignShapeSnapshots.swift (shape-tools DS-4): Design's canvas on `cards` with shape layers, as a file
// holding them opens (drawing them is DS-5's). C (node-4) as a five-point star stretched to 200 × 200 and
// selected: the star, not its box, inside the selection handles. B (node-3) as an arrow from its bottom-left
// to its top-right with a 4 pt stroke, selected: a stroked shaft and head, no filled box. Writes
// design-shape-star- and design-shape-arrow-{light,dark}.png. The tool's options in the inspector,
// design-shape-options-{light,dark}.png, are DesignToolPaletteSnapshots' (DS-2). `DesignShapeSeed` is the
// document RenderBudgetDesignShapeTests drives too. macOS only.
#if canImport(AppKit)
import DesignModel
import SuiteKernel
import SwiftUI
import Testing

@testable import DesignApp

/// `cards` with shape layers, as a file holding them opens.
enum DesignShapeSeed {
    /// C (node-4) a five-point star at 700, 100, 200 × 200, selected.
    static var star: DesignWorkspace {
        DesignTransformSeed.cards(selecting: "node-4", ["node-4": {
            $0.kind = .shape
            $0.shape = ShapeSpec(kind: .star)
            $0.frame = DesignRect(x: 700, y: 100, width: 200, height: 200)
        }])
    }

    /// B (node-3) an arrow from its bottom-left to its top-right, stroked 4 pt, selected.
    static var arrow: DesignWorkspace {
        DesignTransformSeed.cards(selecting: "node-3", ["node-3": {
            $0.kind = .shape
            $0.shape = ShapeSpec(kind: .arrow, head: 24, start: Point(x: 0, y: 1), end: Point(x: 1, y: 0))
            $0.stroke = DesignStroke(color: .black, width: 4)
        }])
    }
}

@MainActor
@Suite struct DesignShapeSnapshots {
    @Test func star() throws {
        let model = DesignShapeSeed.star
        #expect(model.selectedNode?.kind == .shape)
        #expect(model.selectedNode?.shape?.kind == .star)
        try shootCanvas(model, "design-shape-star")
    }

    @Test func arrow() throws {
        let model = DesignShapeSeed.arrow
        #expect(model.selectedNode?.shape?.kind == .arrow)
        #expect(model.selectedNode.map(artworkIsOpen) == true, "an arrow is stroked, never filled")
        try shootCanvas(model, "design-shape-arrow")
    }
}
#endif
