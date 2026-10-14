// DesignMultiSelectSnapshots.swift: Design's canvas with two of three rectangles
// selected by Shift-click (#413): an outline on each, no handles, and one box
// around both. Writes design-multi-select-light.png and -dark.png. macOS only.
import DesignModel
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignMultiSelectSnapshots {
    @Test func twoOfThreeRectangles() throws {
        var model = DesignWorkspace()
        model.newFile()
        drawOnCanvas(&model, .rectangle, from: (120, 160), to: (420, 460))
        let first = try #require(model.selectedNodeID)
        drawOnCanvas(&model, .rectangle, from: (560, 160), to: (860, 460))
        drawOnCanvas(&model, .rectangle, from: (1000, 400), to: (1300, 700))
        let third = try #require(model.selectedNodeID)
        model.selectItem(first)
        model.drag(from: DesignPoint(x: 1100, y: 500), to: DesignPoint(x: 1100, y: 500), modifiers: [.shift])
        model.endDrag()
        #expect(model.selectedNodeIDs == [first, third])
        #expect(model.handle(at: DesignPoint(x: 1300, y: 700)) == nil)
        try shootCanvas(model, "design-multi-select")
    }
}
