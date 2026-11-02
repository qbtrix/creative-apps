// CanvasRulerDragTests.swift: CanvasViewport's ruler toggle and guides dragged
// out of the rulers (#995), as CanvasLayout math. With the rulers hidden the
// layout keeps a band where they were, so the artboard stays where it sat on
// screen; a drag out of a ruler reports the document coordinate across that
// ruler at any zoom and scroll, and whether it ended back over the ruler. No
// SwiftUI rendering. macOS only.
import CoreGraphics
import SuiteUI
import SwiftUI
import Testing

/// A 1000 px square document in a 400 pt viewport with no margin: document 0 sits at the viewport's corner.
private func corner(zoom: Double) -> CanvasLayout {
    CanvasLayout(document: CGSize(width: 1000, height: 1000), zoom: zoom, viewport: CGSize(width: 400, height: 400), margin: 0)
}

@Test func hiddenRulersKeepTheArtboardInPlace() {
    let ruler = SuiteSize.ruler
    let document = CGSize(width: 400, height: 300)
    for zoom in [0.5, 1, 4] {
        let shown = CanvasLayout(document: document, zoom: zoom, viewport: CGSize(width: 1000 - ruler, height: 800 - ruler))
        let hidden = CanvasLayout(document: document, zoom: zoom, viewport: CGSize(width: 1000, height: 800), inset: ruler)
        // Shown, the canvas starts after the ruler band; hidden, at the window's edge. Same place on screen.
        #expect(hidden.origin == CGPoint(x: shown.origin.x + ruler, y: shown.origin.y + ruler), "zoom \(zoom)")
        #expect(hidden.viewport == CGSize(width: 1000, height: 800) && hidden.inset == ruler)
        let point = CGPoint(x: 37, y: 55)
        #expect(hidden.documentPoint(CGPoint(x: point.x + ruler, y: point.y + ruler)) == shown.documentPoint(point))
        // The same scroll range: a pan shows the same part of the document either way.
        #expect(hidden.clamped(CGPoint(x: 9999, y: 9999)) == shown.clamped(CGPoint(x: 9999, y: 9999)))
    }
    #expect(CanvasLayout(document: document, zoom: 1, viewport: CGSize(width: 1000, height: 800)).inset == 0)
}

/// A viewport that never shows rulers (Library's loupe) holds no band: the host fits to the whole
/// size and the artboard sits in its middle, not half a ruler right of and below it (#3688).
@Test func aViewportWithoutARulerBandCentresTheArtboard() {
    let ruler = SuiteSize.ruler
    let size = CGSize(width: 1000, height: 800), document = CGSize(width: 400, height: 300)
    let free = CanvasLayout.inViewport(document: document, zoom: 1, size: size, showsRulers: false, holdsRulerBand: false)
    #expect(free.fitSize == size)
    #expect(free.layout.origin == CGPoint(x: 300, y: 250))
    #expect(free.layout.inset == 0)
    // Hidden rulers that hold their band keep the artboard where the shown ones put it.
    let held = CanvasLayout.inViewport(document: document, zoom: 1, size: size, showsRulers: false, holdsRulerBand: true)
    let shown = CanvasLayout.inViewport(document: document, zoom: 1, size: size, showsRulers: true, holdsRulerBand: true)
    #expect(held.fitSize == CGSize(width: 1000 - ruler, height: 800 - ruler) && held.fitSize == shown.fitSize)
    #expect(held.layout.inset == ruler && shown.layout.inset == 0)
    #expect(held.layout.origin == CGPoint(x: shown.layout.origin.x + ruler, y: shown.layout.origin.y + ruler))
}

@Test func aDragOutOfTheTopRulerPlacesAHorizontalGuide() {
    let one = corner(zoom: 1)
    #expect(one.rulerDrag(.horizontal, .changed, at: CGPoint(x: 120, y: 300), scrolled: .zero)
        == RulerDrag(axis: .horizontal, phase: .changed, position: 300, isOverRuler: false))
    #expect(one.rulerDrag(.horizontal, .ended, at: CGPoint(x: 120, y: 300), scrolled: .zero)
        == RulerDrag(axis: .horizontal, phase: .ended, position: 300, isOverRuler: false))
    #expect(corner(zoom: 2).rulerDrag(.horizontal, .changed, at: CGPoint(x: 120, y: 300), scrolled: .zero).position == 150)
    // Scrolled 100 down, the same view point is 100 px further into the document.
    #expect(one.rulerDrag(.horizontal, .changed, at: CGPoint(x: 120, y: 300), scrolled: CGPoint(x: 0, y: 100)).position == 400)
}

@Test func aDragOutOfTheLeftRulerPlacesAVerticalGuide() {
    let drag = corner(zoom: 2).rulerDrag(.vertical, .changed, at: CGPoint(x: 250, y: 40), scrolled: CGPoint(x: 50, y: 0))
    #expect(drag == RulerDrag(axis: .vertical, phase: .changed, position: 150, isOverRuler: false))
}

@Test func aDragBackOverItsRulerSaysSo() {
    let one = corner(zoom: 1)
    // The top ruler is the band above the viewport (negative y), the left one the band to its left.
    #expect(one.rulerDrag(.horizontal, .ended, at: CGPoint(x: 120, y: -6), scrolled: .zero).isOverRuler)
    #expect(one.rulerDrag(.vertical, .ended, at: CGPoint(x: -6, y: 120), scrolled: .zero).isOverRuler)
    // Over the other ruler is not over its own.
    #expect(!one.rulerDrag(.horizontal, .ended, at: CGPoint(x: -6, y: 120), scrolled: .zero).isOverRuler)
}
