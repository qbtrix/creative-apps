// DesignCanvasSeamSnapshots.swift: the canvas's marks on the `cards` fixture at half size
// (design-window D0-5b): a marquee drawn over A and B mid-drag (design-canvas-marquee), and A
// and B selected together on the fake and on the live services, each layer outlined and the
// dashed box around both (design-canvas-several-fake, design-canvas-several-live). Each writes
// -light.png and -dark.png. The frame names and text come from DesignFrameLabels and
// DesignTextArtwork; every other Design canvas snapshot stays as it was. macOS only.
import SwiftUI
import Testing

@testable import DesignApp
@testable import DesignModel

@MainActor
@Suite struct DesignCanvasSeamSnapshots {
    /// `cards` on `services` with A (node-2) and B (node-3) selected.
    private func aAndB(on services: DesignServices) -> DesignWorkspace {
        var model = DesignFixtures.cards
        model.useServices(services)
        model.selectItem("node-2")
        model.toggleSelection("node-3")
        return model
    }

    @Test func marqueeOverAAndB() throws {
        var model = DesignFixtures.cards
        // What a Move drag from (80, 80) to (520, 240) on Desktop covers, while it is under way.
        let covered = DesignRect(x: 80, y: 80, width: 440, height: 160)
        model.marquee = covered
        let page = try #require(model.selectedPage)
        #expect(model.services.marquee.layers(touching: covered, in: "node-1", on: page) == ["node-2", "node-3"])
        #expect(model.selectedNodeIDs.isEmpty)
        try shootCanvas(model, "design-canvas-marquee")
    }

    @Test func severalOnTheFakes() throws {
        let model = aAndB(on: .fake)
        #expect(model.selectedNodeIDs == ["node-2", "node-3"] && model.hasMultipleSelection)
        #expect(model.selectionBounds == DesignRect(x: 100, y: 100, width: 400, height: 120))
        try shootCanvas(model, "design-canvas-several-fake")
    }

    @Test func severalOnTheLiveServices() throws {
        let model = aAndB(on: .live)
        #expect(model.selectedNodeIDs == ["node-2", "node-3"] && model.hasMultipleSelection)
        #expect(model.selectionBounds == DesignRect(x: 100, y: 100, width: 400, height: 120))
        try shootCanvas(model, "design-canvas-several-live")
    }
}
