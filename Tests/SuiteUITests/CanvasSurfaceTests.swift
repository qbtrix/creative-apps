// CanvasSurfaceTests.swift: CanvasSurface.fitted, the artboard's rect in the
// surface: centered, scaled to fit inside the inset, never above 1, and a
// 0 x 0 artboard drawn as 1 x 1 with no division. No SwiftUI rendering.
// macOS only.
import SwiftUI
import Testing

@testable import SuiteUI

@Test func fittedCentersAnArtboardThatFitsAtScaleOne() {
    let rect = CanvasSurface<EmptyView>.fitted(
        CGSize(width: 400, height: 300), in: CGSize(width: 800, height: 600))
    #expect(rect == CGRect(x: 200, y: 150, width: 400, height: 300))
}

@Test func fittedScalesDownInsideTheInsetAndKeepsTheAspect() {
    let artboard = CGSize(width: 400, height: 300)
    let size = CGSize(width: 200, height: 150)
    // No inset: the whole surface, at half size.
    #expect(CanvasSurface<EmptyView>.fitted(artboard, in: size, inset: 0) == CGRect(x: 0, y: 0, width: 200, height: 150))
    // A 25 pt inset leaves 150 x 100: the height limits, scale 1/3.
    let inset = CanvasSurface<EmptyView>.fitted(artboard, in: size, inset: 25)
    #expect(abs(inset.height - 100) < 0.001)
    #expect(abs(inset.width - 400.0 / 3) < 0.001)
    #expect(abs(inset.midX - 100) < 0.001 && abs(inset.midY - 75) < 0.001)
    #expect(inset.minY >= 25 - 0.001 && inset.maxY <= 125 + 0.001)
    #expect(abs(inset.width / inset.height - 400.0 / 300) < 0.001)
}

@Test func fittedNeverScalesAboveOne() {
    let rect = CanvasSurface<EmptyView>.fitted(
        CGSize(width: 10, height: 20), in: CGSize(width: 1440, height: 900))
    #expect(rect == CGRect(x: 715, y: 440, width: 10, height: 20))
}

@Test func fittedDrawsAnEmptyArtboardAsOnePointWithNoDivision() {
    for empty in [CGSize.zero, CGSize(width: -4, height: 0)] {
        let rect = CanvasSurface<EmptyView>.fitted(empty, in: CGSize(width: 800, height: 600))
        #expect(rect == CGRect(x: 399.5, y: 299.5, width: 1, height: 1))
        #expect(rect.width.isFinite && rect.height.isFinite)
    }
}

@Test func fittedWithNoRoomIsAZeroRectAtTheCenter() {
    let rect = CanvasSurface<EmptyView>.fitted(
        CGSize(width: 400, height: 300), in: CGSize(width: 100, height: 100))
    #expect(rect == CGRect(x: 50, y: 50, width: 0, height: 0))
}
