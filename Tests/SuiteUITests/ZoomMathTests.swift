// ZoomMathTests.swift: the zoom CanvasViewport applies itself (ZoomMath) and
// the view-to-document point math under it (CanvasLayout): the 10% to 3200%
// clamp, the steps, the fit for a wide and a tall artboard, a viewport with no
// room, and the document point under the pointer at 50% and 200%. No SwiftUI
// rendering. macOS only.
import CoreGraphics
import SuiteUI
import Testing

@Test func zoomMathClampsToTenToThirtyTwoHundredPercent() {
    #expect(ZoomMath.clamped(2) == 2)
    #expect(ZoomMath.clamped(0.05) == 0.1)
    #expect(ZoomMath.clamped(-1) == 0.1)
    #expect(ZoomMath.clamped(50) == 32)
    #expect(ZoomMath.clamped(.infinity) == 32)
    #expect(ZoomMath.clamped(.nan) == 1)
}

@Test func zoomMathStepsStayInRange() {
    #expect(ZoomMath.zoomedIn(from: 1) == 1.5)
    #expect(ZoomMath.zoomedOut(from: 1) == 2.0 / 3)
    #expect(ZoomMath.zoomedIn(from: 32) == 32)
    // The 5% stop is below the range.
    #expect(ZoomMath.zoomedOut(from: 0.1) == 0.1)
}

@Test func zoomMathFitsAWideAndATallArtboard() {
    // 1000x600 points of room inside a 32-point margin.
    let viewport = CGSize(width: 1064, height: 664)
    #expect(ZoomMath.fit(document: CGSize(width: 2000, height: 500), in: viewport, margin: 32) == 0.5)
    #expect(ZoomMath.fit(document: CGSize(width: 500, height: 2000), in: viewport, margin: 32) == 0.3)
    // Never above 100%, never below 10%.
    #expect(ZoomMath.fit(document: CGSize(width: 10, height: 10), in: viewport, margin: 32) == 1)
    #expect(ZoomMath.fit(document: CGSize(width: 100_000, height: 100_000), in: viewport, margin: 32) == 0.1)
}

@Test func zoomMathFitInAViewportWithNoRoomIsTheMinimum() {
    #expect(ZoomMath.fit(document: CGSize(width: 800, height: 600), in: .zero) == 0.1)
    #expect(ZoomMath.fit(document: CGSize(width: 800, height: 600), in: CGSize(width: 40, height: 40), margin: 32) == 0.1)
}

@Test func canvasLayoutMapsViewPointsToDocumentPointsAtHalfAndDoubleZoom() {
    let document = CGSize(width: 1000, height: 1000)
    let viewport = CGSize(width: 800, height: 600)
    // At 50% the 500-point artboard sits centered, at (150, 50).
    let half = CanvasLayout(document: document, zoom: 0.5, viewport: viewport, margin: 32)
    #expect(half.documentPoint(CGPoint(x: 250, y: 100)) == CGPoint(x: 200, y: 100))
    // At 200% it scrolls, with the margin before it.
    let double = CanvasLayout(document: document, zoom: 2, viewport: viewport, margin: 32)
    #expect(double.documentPoint(CGPoint(x: 132, y: 82)) == CGPoint(x: 50, y: 25))
}

@Test func canvasLayoutArtboardPointIsNilOffTheArtboard() {
    let half = CanvasLayout(
        document: CGSize(width: 1000, height: 1000), zoom: 0.5, viewport: CGSize(width: 800, height: 600), margin: 32)
    #expect(half.artboardPoint(CGPoint(x: 649, y: 60)) == CGPoint(x: 998, y: 20))
    #expect(half.artboardPoint(CGPoint(x: 149, y: 60)) == nil)
    #expect(half.artboardPoint(CGPoint(x: 650, y: 60)) == nil)
    #expect(half.artboardPoint(CGPoint(x: 300, y: 49)) == nil)
}
