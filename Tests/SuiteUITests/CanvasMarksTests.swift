// CanvasMarksTests.swift: the drag over EK-5's SelectionHandles (CM-4):
// SelectionHandles draws eight handles and a knob, every hit rect is
// SuiteHandleGeometry's at any zoom, a handle drag resizes from the box it
// began on (⇧ keeps the aspect), a rotate zone or the knob turns it, a drag
// ends exactly once and a missed press never, and an aligned box puts every
// handle on the device pixel grid at scale 2. No rendering. macOS only.
import Foundation
import SuiteKernel
import Testing

@testable import SuiteUI

private let rect = CGRect(x: 10, y: 10, width: 100, height: 50)

@Test func selectionHandlesDrawsEightHandlesAndAKnob() {
    let box = Rect(minX: 10, minY: 10, maxX: 110, maxY: 60)
    let marks = SelectionHandles.marks(handles: BoxMath.handles(of: box, size: 4), zoom: 2)
    #expect(marks.filter { $0.handle != .rotate }.count == 8)
    #expect(marks.contains { $0.handle == .rotate })
}

@Test(arguments: [0.25, 1.0, 4.0])
func hitRectsAreSuiteHandleGeometrysAtAnyZoom(zoom: Double) {
    let hits = SelectionHandleDrag.hitRects(rect: rect, zoom: zoom)
    let view = PlaneRect(x: 10 * zoom, y: 10 * zoom, width: 100 * zoom, height: 50 * zoom)
    let geometry = SuiteHandleGeometry().handles(around: view, hitSize: 12, rotateZone: 16)
    #expect(hits.count == HandleKind.allCases.count)
    for kind in HandleKind.allCases {
        let side: CGFloat = kind.rawValue.hasPrefix("rotate") ? 16 : 12
        #expect(hits[kind]?.size == CGSize(width: side, height: side))
        #expect(hits[kind].map { Double($0.minX) } == geometry[kind]?.minX)
    }
}

@Test func aHandleDragResizesFromTheBoxItBeganOn() {
    var drag = SelectionHandleDrag()
    // bottomRight sits at view (220, 120) at zoom 2; 20 pt right is 10 px.
    let start = CGPoint(x: 220, y: 120)
    let r1 = drag.changed(rect: rect, zoom: 2, from: start, to: CGPoint(x: 240, y: 120), shift: false)
    #expect(r1
        == .resize(CGRect(x: 10, y: 10, width: 110, height: 50)))
    // The host has moved the box; the drag still measures from where it began.
    let moved = CGRect(x: 10, y: 10, width: 110, height: 50)
    let r2 = drag.changed(rect: moved, zoom: 2, from: start, to: CGPoint(x: 260, y: 120), shift: false)
    #expect(r2
        == .resize(CGRect(x: 10, y: 10, width: 120, height: 50)))
    let r3 = drag.ended()
    #expect(r3)
    var kept = SelectionHandleDrag()
    guard case let .resize(aspect)? = kept.changed(rect: rect, zoom: 2, from: start, to: CGPoint(x: 260, y: 120), shift: true)
    else { Issue.record("⇧ drag did not resize"); return }
    #expect(abs(aspect.width - 120) <= 1 && abs(aspect.height - 60) <= 1)
}

@Test func aRotateZoneAndTheKnobTurnTheBox() throws {
    var drag = SelectionHandleDrag()
    let square = CGRect(x: 0, y: 0, width: 100, height: 100)
    // Just outside the bottom-right corner, then a clockwise quarter turn about (50, 50).
    let r4 = drag.changed(rect: square, zoom: 1, from: CGPoint(x: 114, y: 114), to: CGPoint(x: -14, y: 114), shift: false)
    #expect(r4
        == .rotate(90))
    let r5 = drag.ended()
    #expect(r5)
    let box = Rect(minX: 0, minY: 0, maxX: 100, maxY: 100)
    let knob = try #require(SelectionHandles.marks(handles: BoxMath.handles(of: box, size: 8), zoom: 1)
        .first { $0.handle == .rotate }?.frame)
    var turn = SelectionHandleDrag()
    let edit = turn.changed(rect: square, zoom: 1, from: CGPoint(x: knob.midX, y: knob.midY),
                            to: CGPoint(x: 150, y: 50), shift: true, knob: knob)
    #expect(edit == .rotate(90))
}

@Test func aDragEndsOnceAndAMissedPressNever() {
    var drag = SelectionHandleDrag()
    let start = CGPoint(x: 220, y: 120)
    for x in [225.0, 230, 235] {
        let r6 = drag.changed(rect: rect, zoom: 2, from: start, to: CGPoint(x: x, y: 120), shift: false)
        #expect(r6 != nil)
    }
    let r7 = drag.ended()
    #expect(r7)
    let r8 = drag.ended()
    #expect(!r8)
    #expect(drag.ends == 1)
    // A press in the middle of the box grabs nothing for the whole drag.
    let r9 = drag.changed(rect: rect, zoom: 2, from: CGPoint(x: 120, y: 70), to: CGPoint(x: 220, y: 120), shift: false)
    #expect(r9 == nil)
    let r10 = drag.changed(rect: rect, zoom: 2, from: CGPoint(x: 120, y: 70), to: CGPoint(x: 230, y: 120), shift: false)
    #expect(r10 == nil)
    let r11 = drag.ended()
    #expect(!r11)
    #expect(drag.ends == 1)
}

@Test(arguments: [0.25, 1.0, 4.0])
func anAlignedBoxPutsEveryHandleOnThePixelGrid(zoom: Double) {
    let odd = CGRect(x: 10.3, y: 7.7, width: 99.1, height: 50.45)
    let box = SelectionHandleDrag.aligned(odd, zoom: zoom, scale: 2)
    let kernel = Rect(minX: Double(box.minX), minY: Double(box.minY), maxX: Double(box.maxX), maxY: Double(box.maxY))
    let marks = SelectionHandles.marks(handles: BoxMath.handles(of: kernel, size: 8 / zoom), zoom: zoom)
    #expect(!marks.isEmpty)
    for mark in marks where mark.handle != .rotate {
        let device = [mark.frame.minX, mark.frame.minY, mark.frame.maxX, mark.frame.maxY].map { Double($0) * 2 }
        #expect(device.allSatisfy { abs($0 - $0.rounded()) < 1e-6 }, "\(mark.handle) at \(mark.frame)")
    }
    #expect(SelectionHandleDrag.aligned(CGRect(x: CGFloat.nan, y: 0, width: 1, height: 1), zoom: zoom, scale: 2).minX.isNaN)
}
