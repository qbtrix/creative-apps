// CanvasFakeTests.swift: the two canvas Fakes (UC7 CanvasNavigating, UC8
// HandleGeometryProviding) give the contracts' main.swift results and keep
// the gap each one has on purpose: the navigator doubles and halves instead
// of stepping ViewerZoom's stops, and the handle geometry knows the four
// corners only (no edges, no rotate zones, no ⇧ aspect, no rotation). The
// live rules' tests (CM-2, CM-3) rely on these gaps. No SwiftUI. macOS only.
import SuiteUI
import Testing

private let nav = FakeCanvasNavigating()
private let geometry = FakeHandleGeometry()
private let box = PlaneRect(x: 0, y: 0, width: 100, height: 100)
private let corners: Set<HandleKind> = [.topLeft, .topRight, .bottomRight, .bottomLeft]

@Test func fakeNavigatorGivesMainSwiftsResults() {
    #expect(nav.zoomedIn(from: 1) == 2)
    #expect(nav.fit(document: PlaneExtent(width: 0, height: 0), in: PlaneExtent(width: 800, height: 600), margin: 32) == 1)
}

@Test func fakeNavigatorDoublesAndHalvesInsteadOfTheStops() {
    // The live rule goes 1 → 1.5 (ViewerZoom's next stop); the Fake skips it.
    #expect(nav.zoomedIn(from: 1) != 1.5)
    #expect(nav.zoomedIn(from: 2) == 4)
    #expect(nav.zoomedOut(from: 1) == 0.5)
    #expect(nav.zoomedOut(from: 0.5) == 0.25)
    #expect(nav.zoomedIn(from: 20) == 32)
    #expect(nav.zoomedOut(from: 0.15) == 0.1)
}

@Test func fakeNavigatorClampsAndMapsANaNTo1() {
    #expect(nav.clamped(.nan) == 1)
    #expect(nav.clamped(0) == 0.1)
    #expect(nav.clamped(100) == 32)
    #expect(nav.clamped(3) == 3)
}

@Test func fakeNavigatorFitsNeverAbove1AndNeverDividesByZero() {
    let viewport = PlaneExtent(width: 800, height: 600)
    #expect(nav.fit(document: PlaneExtent(width: 400, height: 300), in: viewport, margin: 0) == 1)
    #expect(nav.fit(document: PlaneExtent(width: 1600, height: 600), in: viewport, margin: 0) == 0.5)
    #expect(nav.fit(document: PlaneExtent(width: 1472, height: 536), in: viewport, margin: 32) == 0.5)
    #expect(nav.fit(document: PlaneExtent(width: -5, height: 0), in: viewport, margin: 32) == 1)
    #expect(nav.fit(document: PlaneExtent(width: 100, height: 100), in: PlaneExtent(width: 40, height: 40), margin: 32) == 0.1)
    #expect(nav.fit(document: PlaneExtent(width: 100, height: 100), in: PlaneExtent(width: 0, height: 0), margin: 0) == 0.1)
}

@Test func fakeNavigatorMapsViewPointsToDocumentPixels() {
    let origin = PlanePoint(x: 50, y: 50)
    #expect(nav.documentPoint(PlanePoint(x: 150, y: 250), artboardOrigin: origin, zoom: 2) == PlanePoint(x: 50, y: 100))
    #expect(nav.documentPoint(PlanePoint(x: 150, y: 250), artboardOrigin: origin, zoom: 1) == PlanePoint(x: 100, y: 200))
    // A zoom of 0 clamps to 0.1, never a division by zero.
    #expect(nav.documentPoint(PlanePoint(x: 51, y: 50), artboardOrigin: origin, zoom: 0).x == 10)
}

@Test func fakeNavigatorPansATenthAndShiftAWholeViewport() {
    let viewport = PlaneExtent(width: 800, height: 600)
    #expect(nav.panStep(.right, viewport: viewport, modifiers: []) == PlanePoint(x: 80, y: 0))
    #expect(nav.panStep(.left, viewport: viewport, modifiers: []) == PlanePoint(x: -80, y: 0))
    #expect(nav.panStep(.up, viewport: viewport, modifiers: []) == PlanePoint(x: 0, y: -60))
    #expect(nav.panStep(.down, viewport: viewport, modifiers: .shift) == PlanePoint(x: 0, y: 600))
    #expect(nav.panStep(.right, viewport: viewport, modifiers: .option) == PlanePoint(x: 80, y: 0))
}

@Test func fakeGeometryGivesMainSwiftsHit() {
    #expect(geometry.hit(PlanePoint(x: 100, y: 100), around: box, hitSize: 12, rotateZone: 16) == .bottomRight)
    #expect(geometry.hit(PlanePoint(x: -5, y: 5), around: box, hitSize: 12, rotateZone: 16) == .topLeft)
    #expect(geometry.hit(PlanePoint(x: 50, y: 50), around: box, hitSize: 12, rotateZone: 16) == nil)
}

@Test func fakeGeometryDrawsCornerSquaresOnly() {
    let rects = geometry.handles(around: box, hitSize: 12, rotateZone: 16)
    #expect(Set(rects.keys) == corners)
    #expect(rects[.topLeft] == PlaneRect(x: -6, y: -6, width: 12, height: 12))
    #expect(rects[.bottomRight] == PlaneRect(x: 94, y: 94, width: 12, height: 12))
    #expect(rects[.top] == nil)
    #expect(rects[.rotateTopLeft] == nil)
}

@Test func fakeGeometryNeverHitsAnEdgeOrARotateZone() {
    // The live rule hits the top edge's midpoint and the rotate zone outside the corner; the Fake doesn't.
    #expect(geometry.hit(PlanePoint(x: 50, y: 0), around: box, hitSize: 12, rotateZone: 16) == nil)
    #expect(geometry.hit(PlanePoint(x: 100, y: 50), around: box, hitSize: 12, rotateZone: 16) == nil)
    #expect(geometry.hit(PlanePoint(x: -12, y: -12), around: box, hitSize: 12, rotateZone: 16) == nil)
}

@Test func fakeGeometryPicksSomeCornerWhereSquaresOverlap() {
    let tiny = PlaneRect(x: 0, y: 0, width: 4, height: 4)
    let picked = geometry.hit(PlanePoint(x: 0, y: 0), around: tiny, hitSize: 12, rotateZone: 16)
    #expect(picked.map { corners.contains($0) } == true)
}

@Test func fakeGeometryResizesBottomRightOnlyWithoutAspect() {
    let r = PlaneRect(x: 10, y: 20, width: 200, height: 100)
    #expect(geometry.resized(r, handle: .bottomRight, by: PlanePoint(x: 50, y: 25), keepAspect: false)
        == PlaneRect(x: 10, y: 20, width: 250, height: 125))
    // ⇧ is ignored: the live rule gives 250 × 125 here.
    #expect(geometry.resized(r, handle: .bottomRight, by: PlanePoint(x: 50, y: 0), keepAspect: true)
        == PlaneRect(x: 10, y: 20, width: 250, height: 100))
    #expect(geometry.resized(r, handle: .topLeft, by: PlanePoint(x: 50, y: 50), keepAspect: false) == r)
    #expect(geometry.resized(r, handle: .right, by: PlanePoint(x: 50, y: 0), keepAspect: false) == r)
}

@Test func fakeGeometryStopsAtZeroAndNeverRotates() {
    let r = PlaneRect(x: 0, y: 0, width: 200, height: 100)
    let past = geometry.resized(r, handle: .bottomRight, by: PlanePoint(x: -300, y: -300), keepAspect: false)
    #expect(past.extent == PlaneExtent(width: 0, height: 0))
    let center = PlanePoint(x: 0, y: 0)
    #expect(geometry.rotation(from: PlanePoint(x: 10, y: 0), to: PlanePoint(x: 0, y: 10), center: center, snap: false) == 0)
    #expect(geometry.rotation(from: PlanePoint(x: 10, y: 0), to: PlanePoint(x: 0, y: 10), center: center, snap: true) == 0)
}

@Test func handleKindsNameTheKernelHandleTheyDrive() {
    let names = HandleKind.allCases.map { String(describing: $0.editorHandle) }
    #expect(names == [
        "topLeft", "top", "topRight", "right", "bottomRight", "bottom", "bottomLeft", "left",
        "rotate", "rotate", "rotate", "rotate",
    ])
}
