// HandlePointerTests.swift: a selection handle's resize pointer follows the
// box's turn (transform-tools TT-u, #4628). Unturned, each handle points its
// own way; turned 45° or 90° clockwise it points one or two places round
// the ring; 180° flips it; a negative turn goes the other way; a turn rounds
// to the nearest 45°; a rotate zone has no resize pointer; a resize handle
// names its drawn mark. No rendering. macOS only.
import SuiteKernel
import Testing

@testable import SuiteUI

private let resize: [HandleKind] = [.top, .topRight, .right, .bottomRight, .bottom, .bottomLeft, .left, .topLeft]

@Test func unturnedEachHandlePointsItsOwnWay() {
    for kind in resize { #expect(HandlePointer.direction(kind, degrees: 0) == kind) }
}

@Test func aFortyFiveDegreeTurnMovesEachHandleOnePlace() {
    #expect(HandlePointer.direction(.top, degrees: 45) == .topRight)
    #expect(HandlePointer.direction(.right, degrees: 45) == .bottomRight)
    #expect(HandlePointer.direction(.topLeft, degrees: 45) == .top)
}

@Test func aQuarterTurnMovesEachHandleTwoPlaces() {
    #expect(HandlePointer.direction(.top, degrees: 90) == .right)
    #expect(HandlePointer.direction(.left, degrees: 90) == .top)
    #expect(HandlePointer.direction(.bottomRight, degrees: 90) == .bottomLeft)
}

@Test func aHalfTurnFlipsEachHandle() {
    #expect(HandlePointer.direction(.top, degrees: 180) == .bottom)
    #expect(HandlePointer.direction(.topRight, degrees: 180) == .bottomLeft)
    #expect(HandlePointer.direction(.left, degrees: -180) == .right)
}

@Test func aNegativeTurnGoesTheOtherWay() {
    #expect(HandlePointer.direction(.top, degrees: -45) == .topLeft)
    #expect(HandlePointer.direction(.top, degrees: -90) == .left)
    #expect(HandlePointer.direction(.bottomLeft, degrees: -405) == .bottom)
}

@Test func aTurnRoundsToTheNearestFortyFive() {
    #expect(HandlePointer.direction(.top, degrees: 20) == .top)
    #expect(HandlePointer.direction(.top, degrees: 30) == .topRight)
    #expect(HandlePointer.direction(.right, degrees: 400) == .bottomRight)
    #expect(HandlePointer.direction(.right, degrees: .nan) == .right)
}

@Test func aRotateZoneHasNoResizePointer() {
    for kind in [HandleKind.rotateTopLeft, .rotateTopRight, .rotateBottomRight, .rotateBottomLeft] {
        #expect(HandlePointer.direction(kind, degrees: 90) == nil)
        #expect(HandlePointer.mark(kind) == nil)
    }
}

@Test func aResizeHandleNamesItsDrawnMark() {
    #expect(HandlePointer.mark(.topLeft) == .topLeft)
    #expect(HandlePointer.mark(.right) == .right)
    #expect(HandlePointer.mark(.bottom) == .bottom)
}
