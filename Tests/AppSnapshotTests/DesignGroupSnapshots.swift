// DesignGroupSnapshots.swift: Object > Group on `cards` (#416). A and B selected, then Group: the
// editor shows "Group 1" selected on the canvas (its box around both, the rectangles unmoved) and
// in Layers, its row holding A and B. Writes design-group-light.png and -dark.png.
import DesignModel
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignGroupSnapshots {
    @Test func aGroupOfTwoSelected() throws {
        var model = DesignFixtures.cards
        model.selectItem("node-2")
        model.toggleSelection("node-3")
        #expect(model.selectedNodeIDs == ["node-2", "node-3"])
        try model.run(.group)

        let group = try #require(model.selectedNode)
        #expect(model.selectedNodeIDs == [group.id])
        #expect(group.kind == .group)
        #expect(group.name == "Group 1")
        #expect(group.children.map(\.name) == ["A", "B"])
        // The union of A (100, 100, 100 × 80) and B (300, 140, 200 × 80); neither moved.
        #expect(group.frame == DesignRect(x: 100, y: 100, width: 400, height: 120))
        #expect(group.children.map(\.frame) == [
            DesignRect(x: 100, y: 100, width: 100, height: 80), DesignRect(x: 300, y: 140, width: 200, height: 80),
        ])
        #expect(model.undoActionName == "Undo Group")
        try shootEditor(model, "design-group")
    }
}
