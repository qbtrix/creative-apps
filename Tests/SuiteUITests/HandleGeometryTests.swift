// HandleGeometryTests.swift: SuiteHandleGeometry, the live UC8 rule over the
// kernel's BoxMath and HandleHit (CM-2): hit squares stay 12 pt in view
// points at every zoom, edges and rotate zones hit where the Fake never does,
// a rect smaller than a hit square picks its nearest corner, ⇧ keeps the
// aspect from the larger change, a drag past the opposite side stops at the
// kernel's 1 pt, and a turn is clockwise degrees snapped to 15. No SwiftUI.
// macOS only.
import Foundation
import SuiteUI
import Testing

private let geometry = SuiteHandleGeometry()
private let box = PlaneRect(x: 100, y: 100, width: 200, height: 100)

@Test(arguments: [0.25, 1.0, 4.0])
func everyHitSquareIsTwelvePointsAtAnyZoom(zoom: Double) {
    // The rect is in view points, so zoom only changes its size, never the squares'.
    let rect = PlaneRect(x: 10, y: 10, width: 200 * zoom, height: 100 * zoom)
    let squares = geometry.handles(around: rect, hitSize: 12, rotateZone: 16)
    #expect(squares.count == HandleKind.allCases.count)
    for kind in HandleKind.allCases {
        let side = kind.rawValue.hasPrefix("rotate") ? 16.0 : 12.0
        #expect(squares[kind]?.extent == PlaneExtent(width: side, height: side))
    }
    #expect(squares[.bottomRight]?.mid == PlanePoint(x: rect.maxX, y: rect.maxY))
    #expect(squares[.top]?.mid == PlanePoint(x: rect.mid.x, y: rect.minY))
}

@Test func edgesAndRotateZonesHitWhereTheFakeNever() {
    #expect(geometry.hit(PlanePoint(x: 200, y: 103), around: box, hitSize: 12, rotateZone: 16) == .top)
    #expect(geometry.hit(PlanePoint(x: 296, y: 150), around: box, hitSize: 12, rotateZone: 16) == .right)
    #expect(geometry.hit(PlanePoint(x: 305, y: 205), around: box, hitSize: 12, rotateZone: 16) == .bottomRight)
    #expect(geometry.hit(PlanePoint(x: 85, y: 85), around: box, hitSize: 12, rotateZone: 16) == .rotateTopLeft)
    #expect(geometry.hit(PlanePoint(x: 315, y: 215), around: box, hitSize: 12, rotateZone: 16) == .rotateBottomRight)
    #expect(geometry.hit(PlanePoint(x: 200, y: 150), around: box, hitSize: 12, rotateZone: 16) == nil)
    #expect(geometry.hit(PlanePoint(x: 500, y: 500), around: box, hitSize: 12, rotateZone: 16) == nil)
}

@Test func aRectSmallerThanAHitSquarePicksTheNearestCorner() {
    let tiny = PlaneRect(x: 0, y: 0, width: 4, height: 4)
    // (2, 0) sits on the top edge's middle; an overlap never picks an edge.
    let picked = geometry.hit(PlanePoint(x: 2, y: 0), around: tiny, hitSize: 12, rotateZone: 16)
    #expect(picked == .topLeft || picked == .topRight)
    #expect(geometry.hit(PlanePoint(x: 3.5, y: 3.8), around: tiny, hitSize: 12, rotateZone: 16) == .bottomRight)
    #expect(geometry.hit(PlanePoint(x: -1, y: 4.5), around: tiny, hitSize: 12, rotateZone: 16) == .bottomLeft)
}

@Test func shiftKeepsTheAspectFromTheLargerChange() {
    let rect = PlaneRect(x: 0, y: 0, width: 200, height: 100)
    let kept = geometry.resized(rect, handle: .bottomRight, by: PlanePoint(x: 50, y: 0), keepAspect: true)
    #expect(abs(kept.extent.width - 250) <= 1 && abs(kept.extent.height - 125) <= 1)
    #expect(kept.origin == rect.origin)
    let free = geometry.resized(rect, handle: .bottomRight, by: PlanePoint(x: 50, y: 0), keepAspect: false)
    #expect(free.extent == PlaneExtent(width: 250, height: 100))
    let left = geometry.resized(rect, handle: .left, by: PlanePoint(x: 20, y: 7), keepAspect: false)
    #expect(left == PlaneRect(x: 20, y: 0, width: 180, height: 100))
}

@Test func aDragPastTheOppositeSideNeverGoesNegative() {
    let rect = PlaneRect(x: 0, y: 0, width: 200, height: 100)
    let past = geometry.resized(rect, handle: .right, by: PlanePoint(x: -500, y: 0), keepAspect: false)
    #expect(past.extent.width == 1)
    #expect(past.minX == 0)
    let corner = geometry.resized(rect, handle: .topLeft, by: PlanePoint(x: 900, y: 900), keepAspect: false)
    #expect(corner.extent.width >= 0 && corner.extent.height >= 0)
    #expect(geometry.resized(rect, handle: .rotateTopLeft, by: PlanePoint(x: 9, y: 9), keepAspect: false) == rect)
}

@Test func aQuarterTurnIsNinetyAndSnapsToFifteen() {
    let c = PlanePoint(x: 0, y: 0)
    // y down: from the right to straight down is a clockwise quarter turn.
    #expect(geometry.rotation(from: PlanePoint(x: 10, y: 0), to: PlanePoint(x: 0, y: 10), center: c, snap: false) == 90)
    #expect(geometry.rotation(from: PlanePoint(x: 10, y: 0), to: PlanePoint(x: 0, y: -10), center: c, snap: false) == -90)
    let thirteen = 13 * Double.pi / 180
    let end = PlanePoint(x: 10 * cos(thirteen), y: 10 * sin(thirteen))
    #expect(abs(geometry.rotation(from: PlanePoint(x: 10, y: 0), to: end, center: c, snap: false) - 13) < 1e-9)
    #expect(geometry.rotation(from: PlanePoint(x: 10, y: 0), to: end, center: c, snap: true) == 15)
    #expect(geometry.rotation(from: PlanePoint(x: 10, y: 0), to: PlanePoint(x: -10, y: 0), center: c, snap: false) == 180)
    #expect(geometry.rotation(from: c, to: PlanePoint(x: 3, y: 3), center: c, snap: false) == 0)
}
