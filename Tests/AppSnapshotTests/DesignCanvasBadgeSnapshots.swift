// DesignCanvasBadgeSnapshots.swift: Design's canvas feedback before a click (D0-9d). The
// `cards` fixture with A selected shows its size badge, "100 × 80", under the middle of A
// (design-canvas-badge). With the Text tool and the pointer resting at (300, 400), the dashed
// 120 × 24 box a click would place shows there (design-canvas-text-preview). Each writes -light
// and -dark PNGs. The hover store is bound for the render, so the app's shared one is never touched.
import DesignModel
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignCanvasBadgeSnapshots {
    @Test func badge() throws {
        var model = DesignFixtures.cards
        model.selectItem("node-2")
        #expect(model.selectionBadge == "100 × 80")
        try DesignCanvasHover.$bound.withValue(DesignCanvasHover()) {
            try shootCanvas(model, "design-canvas-badge")
        }
    }

    @Test func textPreview() throws {
        var model = DesignFixtures.cards
        model.selectTool(.text)
        let store = DesignCanvasHover()
        store.record(DesignPoint(x: 300, y: 400), modifiers: [], on: model)
        #expect(store.placement == DesignRect(x: 300, y: 400, width: 120, height: 24))
        #expect(store.hint(for: model)?.pointer == .text)
        #expect(store.shows(model))
        try DesignCanvasHover.$bound.withValue(store) {
            try shootCanvas(model, "design-canvas-text-preview")
        }
    }
}
