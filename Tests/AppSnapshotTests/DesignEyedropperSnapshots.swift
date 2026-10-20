// DesignEyedropperSnapshots.swift (eyedropper DY-4): the Eyedropper's loupe over a two-shape design. A new file
// with a rectangle and an ellipse drawn on its Desktop frame, the Eyedropper active and the pointer resting on
// the ellipse: the loupe rings the pointer with the colour under it and its hex ("No colour here" until DY-5's
// adapter bodies read the document), the size chips at the artboard's top left. The hover store is bound for the
// render, so the app's shared one is never touched. Writes design-eyedropper-loupe-light.png and -dark.png.
import DesignModel
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignEyedropperSnapshots {
    @Test func loupe() throws {
        var model = DesignWorkspace()
        model.newFile()
        drawOnCanvas(&model, .rectangle, from: (160, 160), to: (640, 480))
        drawOnCanvas(&model, .ellipse, from: (560, 300), to: (960, 700))
        model.deselect()
        model.selectTool(.eyedropper)
        let store = DesignCanvasHover()
        store.record(DesignPoint(x: 760, y: 500), modifiers: [], on: model)
        #expect(store.loupe(for: model)?.point == DesignPoint(x: 760, y: 500))
        try DesignCanvasHover.$bound.withValue(store) {
            try shootCanvas(model, "design-eyedropper-loupe")
        }
    }
}
