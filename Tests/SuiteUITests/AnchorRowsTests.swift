// AnchorRowsTests.swift (anchor-parenting AN-5): the anchor rows' commands, the
// Parent menu (never the layer or its followers), the mark's hit radius and Shift snap.
import AppKit
import Foundation
import SuiteKernel
import Testing

@testable import SuiteUI

private struct Plain: LayerPayload { var holdsChildren: Bool { false } }

/// a, b following a, c following b, and d on its own; front to back d, c, b, a.
private func chain() -> LayerTree<Plain> {
    var b = LayerNode(id: "b", name: "B", payload: Plain()), c = LayerNode(id: "c", name: "C", payload: Plain())
    (b.followsID, c.followsID) = ("a", "b")
    return LayerTree([LayerNode(id: "a", name: "A", payload: Plain()), b, c, LayerNode(id: "d", name: "D", payload: Plain())])
}

@Test func thePickerSendsAtForEachPoint() {
    #expect(AnchorRows.pointOptions.map(\.id) == BoxAnchor.allCases)
    for point in BoxAnchor.allCases {
        let command = AnchorRows.command(at: point, layer: "box-1")
        #expect(command.id == "transform.set-anchor")
        #expect(command.params == .object(["id": .string("box-1"), "at": .string(point.rawValue)]))
        let option = AnchorRows.pointOptions.first { $0.id == point }
        #expect(option?.identifier == "suite.anchor.at-\(point.rawValue)" && option?.title.isEmpty == false)
    }
}

@Test func xAndYSendOneSetAnchorAtThePoint() {
    let command = AnchorRows.command(x: 12, y: 30, layer: "box-1")
    #expect(command.id == "transform.set-anchor")
    #expect(command.params == .object(["id": .string("box-1"), "x": .number(12), "y": .number(30)]))
}

@Test func theParentMenuListsNoneAndTheOthersButNeverTheLayerOrItsFollowers() {
    let tree = chain()
    #expect(AnchorRows.parentOptions(of: "a", in: tree).map(\.id) == [nil, "d"])
    #expect(AnchorRows.parentOptions(of: "b", in: tree).map(\.id) == [nil, "d", "a"])
    #expect(AnchorRows.parentOptions(of: "c", in: tree).map(\.id) == [nil, "d", "b", "a"])
    #expect(AnchorRows.parentOptions(of: "c", in: tree).map(\.title) == ["None", "D", "B", "A"])
    let none = AnchorRows.command(parent: nil, layer: "b"), a = AnchorRows.command(parent: "a", layer: "b")
    #expect(none.id == "layer.set-parent" && none.params == .object(["id": .string("b"), "parent": .null]))
    #expect(a.params == .object(["id": .string("b"), "parent": .string("a")]))
}

@Test func theMarksHitRadiusIsSixPointsAtAnyZoom() {
    for zoom in [0.25, 1, 4, 0, .nan] {
        #expect(AnchorMark.hitRadius(zoom: zoom) == 6)
    }
    let mark = CGPoint(x: 100, y: 50)
    #expect(AnchorMark.hits(CGPoint(x: 400 + 5.9, y: 200), mark: mark, zoom: 4))
    #expect(!AnchorMark.hits(CGPoint(x: 400 + 6.1, y: 200), mark: mark, zoom: 4))
    #expect(AnchorMark.hits(CGPoint(x: 25, y: 12.5 + 5.9), mark: mark, zoom: 0.25))
}

@Test func aShiftDropSnapsToTheNearestOfTheNinePoints() {
    let snaps: [BoxAnchor: CGPoint] = [.topLeft: CGPoint(x: 0, y: 0), .center: CGPoint(x: 60, y: 40),
                                       .bottomRight: CGPoint(x: 120, y: 80)]
    #expect(AnchorMark.drop(at: CGPoint(x: 8, y: 5), snaps: snaps, shift: true) == .at(.topLeft))
    #expect(AnchorMark.drop(at: CGPoint(x: 70, y: 44), snaps: snaps, shift: true) == .at(.center))
    #expect(AnchorMark.drop(at: CGPoint(x: 8, y: 5), snaps: snaps, shift: false) == .point(CGPoint(x: 8, y: 5)))
    #expect(AnchorMark.drop(at: CGPoint(x: 8, y: 5), snaps: [:], shift: true) == .point(CGPoint(x: 8, y: 5)))
}
