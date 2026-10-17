// DesignMultiSelectSnapshots.swift: two of three rectangles selected with a click and a Shift-click
// (#413): an outline on each selected rectangle, the dashed box around both, and the box's 8
// handles, which the canvas gesture routes to the several-layer resize (select-several S-6).
// Writes design-multi-select-light.png and -dark.png. Then A and B of `cards` in the whole editor:
// the inspector's disabled Distribute rows carry their reason as a visible caption, not only a
// tooltip (#2438). Writes design-multi-select-distribute-light.png and -dark.png.
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
        #expect(model.transformHelp == nil)
        try shootCanvas(model, "design-multi-select")
    }

    @Test func twoLayersSayWhyDistributeIsOff() throws {
        var model = DesignWorkspace()
        model.useServices(.fake)
        let opened = model.openFixture("cards")
        #expect(opened)
        model.selectItem("node-2")
        model.toggleSelection("node-3")
        #expect(model.selectedNodeIDs == ["node-2", "node-3"])
        let reason = "Select three or more layers to distribute."
        let help = Dictionary(uniqueKeysWithValues: DesignDistributeAxis.allCases.compactMap { axis in
            model.help(.distribute(axis)).map { (axis, $0) }
        })
        #expect(help == [.horizontal: reason, .vertical: reason])
        // One caption, once, for both rows; none when Distribute can run or with one layer.
        #expect(DesignAlignBar.distributeCaption(help) == reason)
        #expect(DesignAlignBar.distributeCaption([:]) == nil)
        #expect(DesignAlignBar.distributeCaption(nil) == nil)
        #expect(DesignAlignBar.distributeCaption([.vertical: "B", .horizontal: "A"]) == "A\nB")
        try shootEditor(model, "design-multi-select-distribute")
    }
}
