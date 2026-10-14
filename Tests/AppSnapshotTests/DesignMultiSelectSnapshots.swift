// DesignMultiSelectSnapshots.swift: two of three rectangles selected with a click and a Shift-click
// (#413): an outline on each selected rectangle, the dashed box around both, and no handles.
// Writes design-multi-select-light.png and -dark.png.
import DesignModel
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignMultiSelectSnapshots {
    @Test func twoOfThreeRectanglesSelected() throws {
        var model = DesignWorkspace()
        model.newFile()
        for x in [160.0, 560, 960] { drawOnCanvas(&model, .rectangle, from: (x, 200), to: (x + 320, 520)) }
        let ids = model.selectedPage?.nodes.first?.children.map(\.id) ?? []
        try #require(ids.count == 3)
        model.drag(from: DesignPoint(x: 200, y: 240), to: DesignPoint(x: 200, y: 240))
        model.endDrag()
        model.drag(from: DesignPoint(x: 1000, y: 240), to: DesignPoint(x: 1000, y: 240), modifiers: .shift)
        model.endDrag()
        #expect(model.selectedNodeIDs == [ids[0], ids[2]])
        #expect(model.selectionBounds == DesignRect(x: 160, y: 200, width: 1120, height: 320))
        try shootCanvas(model, "design-multi-select")
    }
}
