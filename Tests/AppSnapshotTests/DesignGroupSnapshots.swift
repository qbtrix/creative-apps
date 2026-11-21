// DesignGroupSnapshots.swift: groups on `cards`. Object > Group (#416): A and B selected, then Group: the
// editor shows "Group 1" selected on the canvas (its box around both, the rectangles unmoved) and in Layers,
// its row holding A and B (design-group). An entered group (area-selection AR-14): A and Title grouped into
// the card, the card entered and Title picked inside it: Title's selection box, and the card's box dimmed
// around it so the scope a click picks in shows (design-group-entered), its edge checked on the pixels where
// no child draws. Each writes -light.png and -dark.png. macOS only.
import AppKit
import SwiftUI
import Testing

@testable import DesignApp
@testable import DesignModel

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

    /// `cards` on the live services with A (node-2) and Title (node-5) grouped into the card, the card entered
    /// and Title picked inside it, as a double-click on Title does; the card's id.
    private func enteredCard() throws -> (DesignWorkspace, String) {
        var model = DesignFixtures.cards
        model.useServices(.live)
        _ = try DesignWorkspace.catalog.run("edit.select", params: .object(["ids": .array([.string("node-2"), .string("node-5")])]), on: &model)
        _ = try DesignWorkspace.catalog.run("object.group", params: .object([:]), on: &model)
        let card = try #require(model.selectedNodeID)
        model.enterGroup()
        _ = try DesignWorkspace.catalog.run("select.pick", params: .object(["x": .number(150), "y": .number(56)]), on: &model)
        #expect(model.groupScope.path == [card])
        #expect(model.selectedNodeIDs == ["node-5"])
        return (model, card)
    }

    @Test func aChildPickedInsideAnEnteredGroup() throws {
        let (model, card) = try enteredCard()
        #expect(model.selectedPage?.nodes.node(card)?.frame == DesignRect(x: 100, y: 40, width: 200, height: 140))
        try shootEditor(model, "design-group-entered")
    }

    /// The card (100, 40) 200 x 140 holds Title (100, 40, 200 x 32) and A (100, 100, 100 x 80). The marks alone at
    /// zoom 1: its bottom edge right of A and its right edge below Title, where no child's box draws, carry a
    /// dimmed accent; the canvas's inside stays clear.
    @Test func theEnteredGroupsEdgeShowsDimmed() throws {
        let (model, _) = try enteredCard()
        let page = try #require(model.selectedPage)
        for scheme in [ColorScheme.light, .dark] {
            let marks = ZStack(alignment: .topLeading) {
                DesignSelectionMarks(model: model, painted: page.painted, zoom: 1)
            }
            let image = try #require(render(marks, scheme: scheme))
            for x in [220, 240, 260, 280] {
                #expect(accentTint(image, across: (178...182).map { (x, $0) }) > 0.1, "bottom edge at x \(x) in \(scheme)")
            }
            for y in [110, 130, 150, 170] {
                #expect(accentTint(image, across: (298...302).map { ($0, y) }) > 0.1, "right edge at y \(y) in \(scheme)")
            }
            #expect(accentTint(image, across: [(250, 140), (260, 150)]) < 0.1, "the card's inside in \(scheme)")
        }
    }
}
