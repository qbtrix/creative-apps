// DesignFrameLabelSnapshots.swift: frame names on the canvas (style-rows ST-5f, #266).
// design-frame-labels: a new file's Desktop frame sits at the page's top edge and
// keeps its name just above it, in the unclipped overlay, while the frame "Card"
// nested in Desktop shows no name. Writes -light.png and -dark.png at half size.
// macOS only.
import SwiftUI
import Testing

@testable import DesignApp
@testable import DesignModel

@MainActor
@Suite struct DesignFrameLabelSnapshots {
    @Test func aTopEdgeFrameKeepsItsNameAboveAndANestedFrameHasNone() throws {
        var model = DesignWorkspace()
        model.newFile()
        let page = try #require(model.selectedPage)
        let desktop = try #require(page.nodes.first)
        let card = try model.addNode(.frame, frame: DesignRect(x: 160, y: 160, width: 480, height: 320), in: desktop.id)
        try model.renameNode(card, to: "Card")
        model.deselect()
        let shown = try #require(model.selectedPage)
        #expect(desktop.frame.y == 0)
        #expect(DesignFrameLabel.labelled(on: shown).map(\.name) == ["Desktop"])
        try shootCanvas(model, "design-frame-labels")
    }
}
