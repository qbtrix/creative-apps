// DesignCanvasFeedbackSnapshots.swift: Design's canvas with the pointer over a layer. The `cards`
// fixture with B selected and the pointer resting inside A: A shows the hover outline, B its
// selection outline and handles. Writes design-canvas-hover-light.png and -dark.png. The hover
// store is bound for the render, so the app's shared one is never touched.
import DesignModel
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignCanvasFeedbackSnapshots {
    @Test func hover() throws {
        var model = DesignFixtures.cards
        model.selectItem("node-3")
        let store = DesignCanvasHover()
        store.record(DesignPoint(x: 150, y: 140), modifiers: [], on: model)
        let hint = try #require(store.hint(for: model))
        #expect(hint.nodeID == "node-2")
        #expect(hint.pointer == .move)
        #expect(model.selectedNodeID == "node-3")
        try DesignCanvasHover.$bound.withValue(store) {
            try shootCanvas(model, "design-canvas-hover")
        }
    }
}
