// CanvasFakeTests.swift: the canvas Fakes (UC7 CanvasNavigating, UC8
// HandleGeometryProviding) give the contracts' main.swift results and keep the
// gap each one has on purpose: the navigating Fake doubles and halves instead
// of walking the live zoom stops; the handle Fake knows corners only, never
// hits an edge or a rotate zone, resizes only from bottomRight and never
// rotates. The live tests (CM-2, CM-3) rely on these gaps. No SwiftUI. macOS
// only.
import SuiteUI
import Testing

@Test func fakeCanvasZoomInGivesMainSwiftsDouble() {
    let n = FakeCanvasNavigating()
    #expect(n.zoomedIn(from: 1) == 2)
    // The gap: 1 doubles to 2, where the live stops give 1.5.
    #expect(n.zoomedIn(from: 2) == 4)
    #expect(n.zoomedOut(from: 1) == 0.5)
    #expect(n.zoomedOut(from: 0.5) == 0.25)
    #expect(n.zoomedIn(from: 32) == 32)
    #expect(n.zoomedOut(from: 0.1) == 0.1)
}

@Test func fakeCanvasClampsAndTreatsNaNAsOne() {
    let n = FakeCanvasNavigating()
    #expect(n.clamped(.nan) == 1)
    #expect(n.clamped(.infinity) == 1)
    #expect(n.clamped(0) == 0.1)
    #expect(n.clamped(100) == 32)
    #expect(n.clamped(3) == 3)
}

@Test func fakeCanvasFitGivesMainSwiftsOneForAnEmptyDocument() {
    let n = FakeCanvasNavigating()
    let viewport = PlaneExtent(width: 800, height: 600)
    #expect(n.fit(document: PlaneExtent(width: 0, height: 0), in: viewport, margin: 32) == 1)
    #expect(n.fit(document: PlaneExtent(width: 400, height: 300), in: viewport, margin: 32) == 1)
    #expect(n.fit(document: PlaneExtent(width: 1472, height: 100), in: viewport, margin: 32) == 0.5)
    #expect(n.fit(document: PlaneExtent(width: 400, height: 300), in: PlaneExtent(width: 60, height: 600), margin: 32) == 0.1)
    #expect(n.fit(document: PlaneExtent(width: 400, height: 300), in: PlaneExtent(width: 0, height: 0), margin: 0) == 0.1)
}

@Test func fakeCanvasMapsViewPointsToDocumentPixels() {
    let n = FakeCanvasNavigating()
    let origin = PlanePoint(x: 20, y: 10)
    #expect(n.documentPoint(PlanePoint(x: 220, y: 110), artboardOrigin: origin, zoom: 2) == PlanePoint(x: 100, y: 50))
    #expect(n.documentPoint(PlanePoint(x: 120, y: 10), artboardOrigin: origin, zoom: .nan) == PlanePoint(x: 100, y: 0))
}

@Test func fakeCanvasPansATenthOrAWholeViewport() {
    let n = FakeCanvasNavigating()
    let v = PlaneExtent(width: 800, height: 600)
    #expect(n.panStep(.right, viewport: v, modifiers: []) == PlanePoint(x: 80, y: 0))
    #expect(n.panStep(.left, viewport: v, modifiers: []) == PlanePoint(x: -80, y: 0))
    #expect(n.panStep(.up, viewport: v, modifiers: []) == PlanePoint(x: 0, y: -60))
    #expect(n.panStep(.down, viewport: v, modifiers: .shift) == PlanePoint(x: 0, y: 600))
}

@Test func fakeHandleHitGivesMainSwiftsBottomRight() {
    let rect = PlaneRect(x: 0, y: 0, width: 100, height: 100)
    let kind = FakeHandleGeometry().hit(PlanePoint(x: 100, y: 100), around: rect, hitSize: 12, rotateZone: 16)
    #expect(kind == .bottomRight)
}

@Test func fakeHandleKnowsCornersOnly() {
    let g = FakeHandleGeometry()
    let rect = PlaneRect(x: 0, y: 0, width: 100, height: 100)
    let handles = g.handles(around: rect, hitSize: 12, rotateZone: 16)
    #expect(Set(handles.keys) == [.topLeft, .topRight, .bottomRight, .bottomLeft])
    #expect(handles[.topLeft] == PlaneRect(x: -6, y: -6, width: 12, height: 12))
    // The gap: an edge midpoint and a rotate zone just outside a corner hit nothing.
    #expect(g.hit(PlanePoint(x: 50, y: 0), around: rect, hitSize: 12, rotateZone: 16) == nil)
    #expect(g.hit(PlanePoint(x: 110, y: 110), around: rect, hitSize: 12, rotateZone: 16) == nil)
    #expect(g.hit(PlanePoint(x: 50, y: 50), around: rect, hitSize: 12, rotateZone: 16) == nil)
}

@Test func fakeHandleResizesFromBottomRightOnlyAndNeverRotates() {
    let g = FakeHandleGeometry()
    let rect = PlaneRect(x: 10, y: 10, width: 200, height: 100)
    #expect(g.resized(rect, handle: .bottomRight, by: PlanePoint(x: 50, y: 0), keepAspect: false)
        == PlaneRect(x: 10, y: 10, width: 250, height: 100))
    // The gap: ⇧ keeps no aspect, and every other handle leaves the rect alone.
    #expect(g.resized(rect, handle: .bottomRight, by: PlanePoint(x: 50, y: 0), keepAspect: true)
        == PlaneRect(x: 10, y: 10, width: 250, height: 100))
    #expect(g.resized(rect, handle: .topLeft, by: PlanePoint(x: 5, y: 5), keepAspect: false) == rect)
    #expect(g.resized(rect, handle: .bottomRight, by: PlanePoint(x: -500, y: -500), keepAspect: false)
        == PlaneRect(x: 10, y: 10, width: 0, height: 0))
    let turn = g.rotation(from: PlanePoint(x: 1, y: 0), to: PlanePoint(x: 0, y: 1), center: PlanePoint(x: 0, y: 0), snap: false)
    #expect(turn == 0)
}
