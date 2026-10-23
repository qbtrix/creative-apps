// CanvasSurfaceTests.swift: CanvasSurface.fitted, where the surface puts its
// artboard. It centres the artboard with the inset clear of every edge,
// scales it down to fit and never up, counts a side that isn't a positive
// finite number as 1, and gives an empty, finite rect when there is no room,
// never dividing by zero. No rendering. macOS only.
import CoreGraphics
import SuiteUI
import SwiftUI
import Testing

private func fitted(_ artboard: CGSize, in size: CGSize, inset: CGFloat = 64) -> CGRect {
    CanvasSurface<EmptyView>.fitted(artboard, in: size, inset: inset)
}

@Test func anArtboardThatFitsSitsCentredAtFullSize() {
    #expect(fitted(CGSize(width: 400, height: 300), in: CGSize(width: 800, height: 600))
        == CGRect(x: 200, y: 150, width: 400, height: 300))
    // A small artboard in a large surface is never scaled up.
    #expect(fitted(CGSize(width: 10, height: 10), in: CGSize(width: 800, height: 600))
        == CGRect(x: 395, y: 295, width: 10, height: 10))
}

@Test func anArtboardThatDoesNotFitShrinksToTheTighterSide() {
    // 200 x 150 less a 64 pt inset leaves 72 x 22; the height binds.
    let rect = fitted(CGSize(width: 400, height: 300), in: CGSize(width: 200, height: 150))
    let scale: CGFloat = 22.0 / 300.0
    #expect(abs(rect.height - 22) < 1e-9)
    #expect(abs(rect.width - 400 * scale) < 1e-9)
    #expect(abs(rect.midX - 100) < 1e-9 && abs(rect.midY - 75) < 1e-9)
    #expect(rect.width <= 72 && rect.height <= 22)
}

@Test func aSideThatIsNotPositiveCountsAsOne() {
    #expect(fitted(.zero, in: CGSize(width: 200, height: 200), inset: 0) == CGRect(x: 99.5, y: 99.5, width: 1, height: 1))
    #expect(fitted(CGSize(width: -5, height: CGFloat.nan), in: CGSize(width: 200, height: 200), inset: 0).size
        == CGSize(width: 1, height: 1))
}

@Test(arguments: [
    CGSize.zero, CGSize(width: -100, height: 50), CGSize(width: 100, height: 100), CGSize(width: CGFloat.nan, height: 600),
    CGSize(width: CGFloat.infinity, height: 600),
])
func noRoomGivesAnEmptyFiniteRect(_ size: CGSize) {
    let rect = fitted(CGSize(width: 400, height: 300), in: size)
    #expect(rect.width == 0 && rect.height == 0)
    #expect(rect.origin.x.isFinite && rect.origin.y.isFinite)
}
