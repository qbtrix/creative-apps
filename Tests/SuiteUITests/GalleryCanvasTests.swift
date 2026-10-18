// GalleryCanvasTests.swift: the canvas pages' log wording (CM-11): the zoom
// pill's percent, whole-pixel points and sizes, and the handle a resize took
// from which edges moved. The journeys SJ9, SJ10, SJ21 and SJ26 read these
// lines. macOS only.
import Foundation
import Testing

@testable import SuiteUI

@Test func theCanvasLogWritesZoomsPointsAndSizes() {
    #expect(GalleryCanvas.percent(2) == "200 %")
    #expect(GalleryCanvas.percent(0.25) == "25 %")
    #expect(GalleryCanvas.point(CGPoint(x: 99.6, y: -0.2)) == "(100,0)")
    #expect(GalleryCanvas.size(CGSize(width: 12, height: 11.5)) == "12×12")
}

@Test func theHandleIsNamedByTheEdgesThatMoved() {
    let box = CGRect(x: 60, y: 60, width: 160, height: 120)
    #expect(GalleryCanvas.handle(from: box, to: CGRect(x: 60, y: 60, width: 185, height: 145)) == "bottomRight")
    #expect(GalleryCanvas.handle(from: box, to: CGRect(x: 40, y: 40, width: 180, height: 140)) == "topLeft")
    #expect(GalleryCanvas.handle(from: box, to: CGRect(x: 60, y: 60, width: 200, height: 120)) == "right")
    #expect(GalleryCanvas.handle(from: box, to: CGRect(x: 60, y: 50, width: 160, height: 130)) == "top")
    #expect(GalleryCanvas.handle(from: box, to: box) == nil)
}
