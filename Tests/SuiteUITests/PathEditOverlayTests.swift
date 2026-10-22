// PathEditOverlayTests.swift (pen-paths PN-2, PN-3): the contour parts join each
// contour's neighbours, close a closed one and keep contours apart; PathGesture
// turns presses, drags and keys into the kernel's PathIntents: a Pen click adds
// a point, a press-drag adds one with a handle, a click near the first anchor
// closes, an anchor drag moves under one token, Option breaks a handle, Delete
// removes. Pure value tests. macOS only.
import SuiteKernel
@testable import SuiteUI
import SwiftUI
import Testing

private func corner(_ x: Double, _ y: Double) -> VectorAnchor { VectorAnchor(point: Point(x: x, y: y)) }

private func contour(_ xs: [Double], closed: Bool) -> VectorContour {
    VectorContour(anchors: xs.map { corner($0, 0) }, closed: closed)
}

private func context(_ tool: PenTool, draft: [VectorAnchor]? = nil, selected: [AnchorRef] = [], zoom: Double = 2) -> PathContext {
    let path = PathInEdit(id: "p", path: VectorPath(contours: [contour([0, 50, 100], closed: false)]), toDocument: .identity)
    return PathContext(draft: draft.map { PenDraft(contour: VectorContour(anchors: $0, closed: false), scale: zoom) },
                       path: path, selection: Selection(selected), tool: tool, zoom: zoom)
}

private let a1 = AnchorRef(contour: 0, index: 1)

@Test func contourPartsJoinNeighboursAndCloseClosedOnes() {
    let parts = PathMarks.parts([contour([0, 10, 20], closed: true), contour([30, 40], closed: false)], toView: .identity)
    #expect(parts.anchors.map(\.point.x) == [0, 10, 20, 30, 40])
    #expect(parts.segments == [
        PathSegment(from: 0, to: 1), PathSegment(from: 1, to: 2), PathSegment(from: 2, to: 0),
        PathSegment(from: 3, to: 4),
    ])
}

@Test func shortContoursAddNoSegment() {
    let parts = PathMarks.parts([contour([], closed: true), contour([5], closed: true)], toView: .identity)
    #expect(parts.anchors.count == 1)
    #expect(parts.segments.isEmpty)
    #expect(PenTool.allCases.map(\.title) == ["Pen", "Direct Selection"])
}

@Test func penClickEmitsOnePenAdd() {
    var gesture = PathGesture()
    let pressed = gesture.press(at: CGPoint(x: 20, y: 30), hit: nil, modifiers: [], token: "t", in: context(.pen, draft: []))
    let released = gesture.release(at: CGPoint(x: 20, y: 30), modifiers: [])
    #expect(pressed + released == [.penAdd(Point(x: 10, y: 15), handleOut: nil)])
}

@Test func penPressDragEmitsPenAddWithAHandle() {
    var gesture = PathGesture()
    var intents = gesture.press(at: CGPoint(x: 20, y: 30), hit: nil, modifiers: [], token: "t", in: context(.pen, draft: []))
    intents += gesture.drag(to: CGPoint(x: 40, y: 30), modifiers: [])
    intents += gesture.drag(to: CGPoint(x: 60, y: 30), modifiers: [])
    intents += gesture.release(at: CGPoint(x: 60, y: 30), modifiers: [])
    #expect(intents == [.penAdd(Point(x: 10, y: 15), handleOut: Point(x: 30, y: 15))])
}

@Test func clickNearTheFirstAnchorClosesInsteadOfAddingAFourth() {
    let draft = [corner(0, 0), corner(100, 0), corner(100, 100)]
    var gesture = PathGesture()
    // (2, 2) in view is 2.8 points from the first anchor's (0, 0): within 4, so it closes.
    let near = gesture.press(at: CGPoint(x: 2, y: 2), hit: nil, modifiers: [], token: "t", in: context(.pen, draft: draft))
        + gesture.release(at: CGPoint(x: 2, y: 2), modifiers: [])
    #expect(near == [.close])
    #expect(PathGesture.hint(at: CGPoint(x: 2, y: 2), hit: nil, in: context(.pen, draft: draft)) == .close)
    // 5 points away adds a point; two anchors never close.
    let far = gesture.press(at: CGPoint(x: 5, y: 0), hit: nil, modifiers: [], token: "t", in: context(.pen, draft: draft))
        + gesture.release(at: CGPoint(x: 5, y: 0), modifiers: [])
    #expect(far == [.penAdd(Point(x: 2.5, y: 0), handleOut: nil)])
    #expect(!PathGesture.closes(at: CGPoint(x: 1, y: 1), in: context(.pen, draft: Array(draft.prefix(2)))))
}

@Test func draggingASelectedAnchorMovesUnderOneToken() {
    var gesture = PathGesture()
    var intents = gesture.press(at: CGPoint(x: 100, y: 0), hit: .anchor(a1), modifiers: [], token: "drag-1",
                                in: context(.directSelect, selected: [a1]))
    #expect(intents.isEmpty)
    intents += gesture.drag(to: CGPoint(x: 110, y: 4), modifiers: [])
    intents += gesture.drag(to: CGPoint(x: 120, y: 10), modifiers: [])
    intents += gesture.release(at: CGPoint(x: 120, y: 10), modifiers: [])
    #expect(intents == [.move(dx: 5, dy: 2, drag: "drag-1"), .move(dx: 5, dy: 3, drag: "drag-1")])
    // An unselected anchor is selected first.
    let fresh = gesture.press(at: CGPoint(x: 100, y: 0), hit: .anchor(a1), modifiers: [], token: "drag-2", in: context(.directSelect))
    #expect(fresh == [.select(anchors: [a1], rect: nil, extend: false)])
}

@Test func optionOnAHandleBreaksIt() {
    var gesture = PathGesture()
    _ = gesture.press(at: CGPoint(x: 100, y: 20), hit: .handle(a1, .handleOut), modifiers: [], token: "h", in: context(.directSelect))
    let broken = gesture.drag(to: CGPoint(x: 100, y: 40), modifiers: .option)
    #expect(broken == [.handle(a1, .handleOut, to: Point(x: 50, y: 20), breaking: true, drag: "h")])
    let smooth = gesture.drag(to: CGPoint(x: 100, y: 60), modifiers: [])
    #expect(smooth == [.handle(a1, .handleOut, to: Point(x: 50, y: 30), breaking: false, drag: "h")])
}

@Test func keysMapToIntents() {
    let selected = context(.directSelect, selected: [a1])
    #expect(PathGesture.key(.delete, modifiers: [], in: selected) == [.remove])
    #expect(PathGesture.key(.delete, modifiers: [], in: context(.directSelect)).isEmpty)
    #expect(PathGesture.key(.up, modifiers: .shift, in: selected) == [.move(dx: 0, dy: -10, drag: nil)])
    #expect(PathGesture.key(.right, modifiers: [], in: selected) == [.move(dx: 1, dy: 0, drag: nil)])
    #expect(PathGesture.key(.returnKey, modifiers: [], in: context(.pen, draft: [corner(0, 0)])) == [.finish])
    #expect(PathGesture.key(.escape, modifiers: [], in: context(.pen, draft: [corner(0, 0)])) == [.cancel])
    #expect(PathGesture.key(.escape, modifiers: [], in: selected) == [.select(anchors: [], rect: nil, extend: false)])
}

@Test func emptyDragMarqueesAndAClickClears() {
    var gesture = PathGesture()
    let marquee = gesture.press(at: CGPoint(x: 40, y: 40), hit: nil, modifiers: [], token: "m", in: context(.directSelect))
        + gesture.drag(to: CGPoint(x: 0, y: 10), modifiers: [])
        + gesture.release(at: CGPoint(x: 0, y: 10), modifiers: .shift)
    #expect(marquee == [.select(anchors: nil, rect: Rect(minX: 0, minY: 5, maxX: 20, maxY: 20), extend: true)])
    let click = gesture.press(at: CGPoint(x: 40, y: 40), hit: nil, modifiers: [], token: "c", in: context(.directSelect))
        + gesture.release(at: CGPoint(x: 40, y: 40), modifiers: [])
    #expect(click == [.select(anchors: [], rect: nil, extend: false)])
}

@Test func aStandInContourIsTheKernelContourItDescribes() {
    let smooth = PathAnchor(point: CGPoint(x: 10, y: 20), kind: .smooth, handleIn: CGPoint(x: 5, y: 20), handleOut: CGPoint(x: 15, y: 20))
    let standIn = PathContourStandIn(anchors: [PathAnchor(point: CGPoint(x: 0, y: 0), kind: .corner), smooth], closed: true)
    #expect(standIn.contour == VectorContour(anchors: [
        corner(0, 0),
        VectorAnchor(point: Point(x: 10, y: 20), handleIn: Point(x: 5, y: 20), handleOut: Point(x: 15, y: 20), kind: .smooth),
    ], closed: true))
}
