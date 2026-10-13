// DesignResizeSnapshots.swift: resizing on the canvas. A rectangle is drawn, then a Move drag that
// starts on its bottom-right handle stretches it, and it stays selected with its handles on the new
// corners. Writes design-resize-light.png and -dark.png.
import DesignModel
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignResizeSnapshots {
    @Test func rectangleDraggedByItsBottomRightHandle() throws {
        var model = DesignWorkspace()
        model.newFile()
        drawOnCanvas(&model, .rectangle, from: (160, 160), to: (640, 480))
        let rectangle = try #require(model.selectedNodeID)
        drawOnCanvas(&model, .move, from: (640, 480), to: (760, 560))
        #expect(model.selectedNodeID == rectangle)
        #expect(model.selectedNode?.frame == DesignRect(x: 160, y: 160, width: 600, height: 400))
        #expect(model.undoActionName == "Undo Resize")
        try shootCanvas(model, "design-resize")
    }
}
