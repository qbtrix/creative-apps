// PathEditOverlayTests.swift (pen-paths PN-2): the contour stub joins each
// contour's neighbours, closes a closed one, and keeps contours apart. Geometry
// only. macOS only.
import SuiteUI
import SwiftUI
import Testing

private func contour(_ xs: [Double], closed: Bool) -> PathContourStandIn {
    PathContourStandIn(anchors: xs.map { PathAnchor(point: CGPoint(x: $0, y: 0), kind: .corner) }, closed: closed)
}

@Test func contourPartsJoinNeighboursAndCloseClosedOnes() {
    let parts = PathMarks.parts([contour([0, 10, 20], closed: true), contour([30, 40], closed: false)])
    #expect(parts.anchors.map(\.point.x) == [0, 10, 20, 30, 40])
    #expect(parts.segments == [
        PathSegment(from: 0, to: 1), PathSegment(from: 1, to: 2), PathSegment(from: 2, to: 0),
        PathSegment(from: 3, to: 4),
    ])
}

@Test func shortContoursAddNoSegment() {
    let parts = PathMarks.parts([contour([], closed: true), contour([5], closed: true)])
    #expect(parts.anchors.count == 1)
    #expect(parts.segments.isEmpty)
    #expect(PenTool.allCases.map(\.title) == ["Pen", "Direct Selection"])
}
