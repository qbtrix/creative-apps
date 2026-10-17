// DesignPasteboardSnapshots.swift: Edit > Copy and Paste of a frame with two children (#415). A new
// file's Desktop holds the frame "Card" with a rectangle and an ellipse; Card is copied, the
// selection cleared, and the bytes pasted: they land in Desktop, where Card came from, and since
// Card is still there the copy sits beside it at +10, +10, selected, with new ids and the same
// names and relative places. Writes design-paste-light.png and -dark.png.
import DesignModel
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignPasteboardSnapshots {
    @Test func aFrameWithTwoChildrenPastedBesideTheOriginal() throws {
        var model = DesignWorkspace()
        model.newFile()
        let card = try model.addNode(.frame, frame: DesignRect(x: 200, y: 200, width: 480, height: 320), in: "node-1")
        try model.addNode(.rectangle, frame: DesignRect(x: 240, y: 240, width: 160, height: 120), in: card)
        try model.addNode(.ellipse, frame: DesignRect(x: 440, y: 320, width: 180, height: 160), in: card)
        model.selectItem(card)
        let original = try #require(model.selectedNode)
        let data = try model.copySelection()
        model.deselect()
        try model.paste(data)

        let desktop = try #require(model.selectedPage?.nodes.first)
        let copy = try #require(model.selectedNode)
        #expect(desktop.children.map(\.id) == [card, copy.id])
        #expect(copy.name == original.name)
        #expect(copy.frame == DesignRect(x: 210, y: 210, width: 480, height: 320))
        #expect(copy.children.map(\.name) == original.children.map(\.name))
        #expect(copy.children.map(\.frame) == original.children.map { $0.frame.offsetBy(10, 10) })
        #expect(Set(copy.children.map(\.id)).isDisjoint(with: original.children.map(\.id)))
        #expect(model.undoActionName == "Undo Paste")
        try shootEditor(model, "design-paste")
    }
}

extension DesignRect {
    fileprivate func offsetBy(_ dx: Double, _ dy: Double) -> DesignRect {
        DesignRect(x: x + dx, y: y + dy, width: width, height: height)
    }
}
