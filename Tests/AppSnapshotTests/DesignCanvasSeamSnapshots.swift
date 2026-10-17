// DesignCanvasSeamSnapshots.swift: the canvas's marks on the `cards` fixture at half size
// (design-window D0-5b): a marquee drawn over A and B mid-drag (design-canvas-marquee), and A
// and B selected together on the fake and on the live services, each layer outlined in accent and
// a solid accent box with handles around both (design-canvas-several-fake,
// design-canvas-several-live), its edge checked on the pixels to carry the accent. Each writes
// -light.png and -dark.png. The frame names and text come from DesignFrameLabels and
// DesignTextArtwork; every other Design canvas snapshot stays as it was. macOS only.
import AppKit
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

    /// #2365: the several-layer box is a committed selection, so its edge is the accent, not
    /// neutral dashes. The marks alone at zoom 1, one pixel per point: the box is (100, 100)
    /// 400 x 120, and the pixels across its top and left edges, away from the handles, are blue.
    @Test func severalBoxEdgeCarriesTheAccent() throws {
        let model = aAndB(on: .live)
        let page = try #require(model.selectedPage)
        for scheme in [ColorScheme.light, .dark] {
            let marks = ZStack(alignment: .topLeading) {
                DesignSelectionMarks(model: model, painted: page.painted, zoom: 1)
            }
            let image = try #require(render(marks, scheme: scheme))
            for x in [150, 200, 250, 350, 400, 450] {
                #expect(accentTint(image, across: (98...102).map { (x, $0) }) > 0.3, "top edge at x \(x) in \(scheme)")
            }
            for y in [120, 140, 180, 200] {
                #expect(accentTint(image, across: (98...102).map { ($0, y) }) > 0.3, "left edge at y \(y) in \(scheme)")
            }
        }
    }
}

/// The strongest blue-over-red lean among `pixels`: about 0.85 for the accent #1877F2, 0 for a
/// neutral grey, black or white.
@MainActor
private func accentTint(_ image: NSBitmapImageRep, across pixels: [(Int, Int)]) -> Double {
    pixels.compactMap { image.colorAt(x: $0.0, y: $0.1)?.usingColorSpace(.sRGB) }
        .map { Double($0.blueComponent - $0.redComponent) }
        .max() ?? 0
}
