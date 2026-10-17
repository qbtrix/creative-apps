// DesignMarqueeSnapshots.swift: a marquee under way on `cards` (live services):
// pressed on the Desktop frame's background at (80, 80) and dragged to
// (520, 240), not yet released. The canvas draws the Model's `marquee` (the
// accent rectangle) and the layers it touches so far, A and B, selected: a
// dashed outline on each and the box's 8 handles. Writes
// design-marquee-light.png and -dark.png. macOS only.
import DesignModel
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignMarqueeSnapshots {
    @Test func midMarqueeOverAAndB() throws {
        var model = DesignFixtures.cards
        let (start, end) = (DesignPoint(x: 80, y: 80), DesignPoint(x: 520, y: 240))
        model.drag(from: start, to: start)
        model.drag(from: start, to: end)
        #expect(model.marquee == DesignRect(x: 80, y: 80, width: 440, height: 160))
        #expect(model.selectedNodeIDs == ["node-2", "node-3"])
        #expect(model.transformHelp == nil)
        try shootCanvas(model, "design-marquee")
    }
}
