// DesignMoveLiftPaintTests.swift: the canvas mid-move-drag paints the whole page. A new file's white
// Desktop frame holds an ellipse near its bottom and then a #D9D9D9 rectangle (309 × 211); the
// rectangle is pressed with Move and dragged 100 pt right and down, not released, so the canvas
// draws the lift (DesignPageArtwork's under, run and over parts, DesignWorkspace.moveLift). Read
// from DesignCanvas at 50%: Desktop's fill is white near its bottom and where the rectangle was,
// the ellipse still shows, and the rectangle is painted at its moved place. The parts once laid
// out one above the other, a third of the page each, so only a band of Desktop and no rectangle
// showed (captain, 11-01). macOS only.
#if canImport(AppKit)
import AppKit
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignMoveLiftPaintTests {
    @Test func aMoveDragPaintsTheWholePage() throws {
        var model = DesignWorkspace()
        model.newFile()
        drawOnCanvas(&model, .ellipse, from: (600, 760), to: (900, 960))
        drawOnCanvas(&model, .rectangle, from: (200, 200), to: (509, 411))
        try #require(model.selectedNode?.kind == .rectangle)
        model.selectTool(.move)
        let press = DesignPoint(x: 354, y: 305)
        model.drag(from: press, to: press, modifiers: .noSnap)
        model.drag(from: press, to: DesignPoint(x: 454, y: 405), modifiers: .noSnap)
        try #require(model.moveLift != nil, "the drag is a lifted move")
        let page = try #require(model.selectedPage)

        let zoom = 0.5
        let image = try #require(render(DesignCanvas(model: model, zoom: zoom), scheme: .light))
        // The canvas at 1440 × 900 with its rulers; at 50% the page fits, so nothing is scrolled.
        let (layout, _) = CanvasLayout.inViewport(
            document: CGSize(width: page.frameWidth, height: page.frameHeight), zoom: zoom,
            size: CGSize(width: 1440, height: 900), showsRulers: true, holdsRulerBand: true)
        func color(_ x: Double, _ y: Double) -> NSColor? {
            let px = Int(SuiteSize.ruler + layout.origin.x + zoom * x), py = Int(SuiteSize.ruler + layout.origin.y + zoom * y)
            return image.colorAt(x: px, y: py)?.usingColorSpace(.sRGB)
        }
        // Every pixel of the 32 pt square around (x, y) is `v`: one checkerboard tile is smaller, so its two greys fail.
        func near(_ x: Double, _ y: Double, _ v: Double) -> Bool {
            stride(from: -16.0, through: 16, by: 2).allSatisfy { dy in
                stride(from: -16.0, through: 16, by: 2).allSatisfy { dx in
                    guard let c = color(x + dx, y + dy) else { return false }
                    return [c.redComponent, c.greenComponent, c.blueComponent].allSatisfy { abs(Double($0) - v) < 0.03 }
                }
            }
        }
        let white = 1.0, shape = 217.0 / 255
        try shootCanvas(model, "design-canvas-move-lift", zoom: zoom)
        #expect(near(100, 900, white), "Desktop's fill near its bottom: \(String(describing: color(100, 900)))")
        #expect(near(1300, 600, white), "Desktop's fill in its middle: \(String(describing: color(1300, 600)))")
        #expect(near(250, 250, white), "Desktop's fill where the rectangle was: \(String(describing: color(250, 250)))")
        #expect(near(750, 860, shape), "the ellipse: \(String(describing: color(750, 860)))")
        #expect(near(454, 405, shape), "the moved rectangle's centre: \(String(describing: color(454, 405)))")
    }
}
#endif
