// CanvasPanTests.swift: the pan math behind CanvasViewport's Space-drag and
// arrow keys (CanvasLayout's clamped and panned): the content follows the
// pointer, an arrow steps a tenth of the viewport (Shift a whole one), and
// no pan scrolls past the scrollable area; and SuiteCanvasNavigating's
// panStep, the same step as a vector. No SwiftUI rendering. macOS only.
import CoreGraphics
import SuiteUI
import SwiftUI
import Testing

/// A 2000 pt square artboard in an 800x600 viewport: it scrolls 1264 across and 1464 down.
private let zoomedIn = CanvasLayout(
    document: CGSize(width: 1000, height: 1000), zoom: 2, viewport: CGSize(width: 800, height: 600), margin: 32)

@Test func canvasPanDragMovesTheContentWithThePointer() {
    // Dragging right and up shows more of the left and the bottom.
    #expect(zoomedIn.panned(from: CGPoint(x: 100, y: 100), by: CGSize(width: 30, height: -20)) == CGPoint(x: 70, y: 120))
}

@Test func canvasPanDragStopsAtTheContentEdges() {
    #expect(zoomedIn.panned(from: CGPoint(x: 10, y: 10), by: CGSize(width: 50, height: 50)) == .zero)
    #expect(
        zoomedIn.panned(from: CGPoint(x: 1260, y: 1460), by: CGSize(width: -50, height: -50))
            == CGPoint(x: 1264, y: 1464))
}

@Test func canvasPanArrowsStepATenthOfTheViewport() {
    let start = CGPoint(x: 500, y: 500)
    #expect(zoomedIn.panned(from: start, key: .rightArrow, page: false) == CGPoint(x: 580, y: 500))
    #expect(zoomedIn.panned(from: start, key: .leftArrow, page: false) == CGPoint(x: 420, y: 500))
    #expect(zoomedIn.panned(from: start, key: .downArrow, page: false) == CGPoint(x: 500, y: 560))
    #expect(zoomedIn.panned(from: start, key: .upArrow, page: false) == CGPoint(x: 500, y: 440))
}

@Test func canvasPanShiftArrowsStepAWholeViewportAndClamp() {
    #expect(zoomedIn.panned(from: CGPoint(x: 500, y: 500), key: .downArrow, page: true) == CGPoint(x: 500, y: 1100))
    #expect(zoomedIn.panned(from: CGPoint(x: 500, y: 1100), key: .downArrow, page: true) == CGPoint(x: 500, y: 1464))
    #expect(zoomedIn.panned(from: CGPoint(x: 500, y: 500), key: .leftArrow, page: true) == CGPoint(x: 0, y: 500))
}

@Test func canvasPanIgnoresKeysThatAreNotArrows() {
    for key: KeyEquivalent in [.space, .return, .escape, "a"] {
        #expect(zoomedIn.panned(from: .zero, key: key, page: false) == nil)
    }
}

@Test func canvasPanCannotMoveAFittingDocument() {
    let fits = CanvasLayout(document: CGSize(width: 400, height: 300), zoom: 0.5, viewport: CGSize(width: 800, height: 600))
    #expect(fits.panned(from: .zero, by: CGSize(width: -300, height: -300)) == .zero)
    #expect(fits.panned(from: .zero, key: .downArrow, page: true) == .zero)
    #expect(fits.clamped(CGPoint(x: 40, y: -40)) == .zero)
}

@Test func suiteCanvasArrowPansATenthOfTheViewport() {
    let n = SuiteCanvasNavigating()
    let v = PlaneExtent(width: 800, height: 600)
    #expect(n.panStep(.right, viewport: v, modifiers: []) == PlanePoint(x: 80, y: 0))
    #expect(n.panStep(.left, viewport: v, modifiers: []) == PlanePoint(x: -80, y: 0))
    #expect(n.panStep(.down, viewport: v, modifiers: []) == PlanePoint(x: 0, y: 60))
    #expect(n.panStep(.up, viewport: v, modifiers: [.option, .command]) == PlanePoint(x: 0, y: -60))
}

@Test func suiteCanvasShiftArrowPansAWholeViewport() {
    let n = SuiteCanvasNavigating()
    let v = PlaneExtent(width: 800, height: 600)
    #expect(n.panStep(.right, viewport: v, modifiers: .shift) == PlanePoint(x: 800, y: 0))
    #expect(n.panStep(.left, viewport: v, modifiers: .shift) == PlanePoint(x: -800, y: 0))
    #expect(n.panStep(.up, viewport: v, modifiers: .shift) == PlanePoint(x: 0, y: -600))
    #expect(n.panStep(.down, viewport: v, modifiers: [.shift, .option]) == PlanePoint(x: 0, y: 600))
}

@Test func suiteCanvasPanStepMatchesTheViewportsArrowScroll() {
    // The vector panStep gives is the move CanvasLayout's panned(from:key:page:) makes, away from the edges.
    let n = SuiteCanvasNavigating()
    let step = n.panStep(.right, viewport: PlaneExtent(width: 800, height: 600), modifiers: [])
    let moved = zoomedIn.panned(from: CGPoint(x: 500, y: 500), key: .rightArrow, page: false)
    #expect(moved == CGPoint(x: 500 + step.x, y: 500 + step.y))
}
