// TransformRowsTests.swift: the inspector's transform rows (transform-tools
// TT-3). Each row edit asks for exactly one TransformIntent: a typed
// rotation one `.rotate` by the difference, X, Y, W and H one `.set` that
// keeps the rest of the box; a value that changes nothing or a size under 1
// asks for none. Flip Horizontal and Flip Vertical each ask for one `.flip`,
// and with `flipHelp` set both are disabled and say why; with no selection
// every row is disabled and says why. No rendering. macOS only.
import Foundation
import SuiteKernel
import Testing

@testable import SuiteUI

private let item = TransformBox(box: Rect(minX: 100, minY: 80, maxX: 300, maxY: 200), degrees: 30)

@Test func aTypedRotationAsksForOneRotate() {
    #expect(TransformRows.intent(.rotation, to: 45, from: item, drag: "d") == .rotate(by: 15, drag: "d"))
    #expect(TransformRows.intent(.rotation, to: 30, from: item, drag: nil) == nil)
}

@Test func xYWAndHAskForOneSetThatKeepsTheRest() {
    let moved = TransformRows.intent(.x, to: 120, from: item, drag: nil)
    #expect(moved == .set(TransformBox(box: Rect(minX: 120, minY: 80, maxX: 320, maxY: 200), degrees: 30), drag: nil))
    let wider = TransformRows.intent(.w, to: 240, from: item, drag: "d")
    #expect(wider == .set(TransformBox(box: Rect(minX: 100, minY: 80, maxX: 340, maxY: 200), degrees: 30), drag: "d"))
    let taller = TransformRows.intent(.h, to: 60, from: item, drag: nil)
    #expect(taller == .set(TransformBox(box: Rect(minX: 100, minY: 80, maxX: 300, maxY: 140), degrees: 30), drag: nil))
    #expect(TransformRows.intent(.y, to: 80, from: item, drag: nil) == nil)
}

@Test func aSizeUnderOneAsksForNothingAndTheRowSaysWhy() {
    #expect(TransformRows.intent(.w, to: 0.5, from: item, drag: nil) == nil)
    #expect(TransformRows.intent(.h, to: .nan, from: item, drag: nil) == nil)
    #expect(TransformRows.range(.w).lowerBound == 1)
    #expect(TransformRows.rangeHelp(.w) == "Type a number from 1 to 100000")
    #expect(TransformRows.rangeHelp(.rotation) == "Type a number from -180° to 180°")
}

@Test @MainActor func eachFlipAsksForOneFlip() {
    var asked = [TransformIntent]()
    let actions = TransformRows.flips(selection: item, help: nil, flipHelp: nil) { asked.append($0) }
    #expect(actions.map(\.identifier) == ["suite.transform.flip-horizontal", "suite.transform.flip-vertical"])
    #expect(actions.allSatisfy { $0.isEnabled })
    actions.first?.perform()
    #expect(asked == [.flip(.horizontal)])
    actions.last?.perform()
    #expect(asked == [.flip(.horizontal), .flip(.vertical)])
}

@Test @MainActor func flipHelpDisablesBothFlipsWithIt() {
    let actions = TransformRows.flips(selection: item, help: nil, flipHelp: "Groups can't be flipped yet.") { _ in }
    #expect(actions.count == 2)
    #expect(actions.allSatisfy { !$0.isEnabled && $0.help == "Groups can't be flipped yet." })
}

@Test @MainActor func noSelectionDisablesEveryRowAndSaysWhy() {
    #expect(TransformRows.reason(selection: nil, help: nil) == TransformRows.noSelection)
    #expect(TransformRows.reason(selection: item, help: "Locked") == "Locked")
    #expect(TransformRows.reason(selection: item, help: nil) == nil)
    let actions = TransformRows.flips(selection: nil, help: nil, flipHelp: nil) { _ in }
    #expect(actions.allSatisfy { !$0.isEnabled && $0.help == TransformRows.noSelection })
}

@Test func theRowsReadTheBox() {
    #expect(TransformRow.allCases.map { TransformRows.value($0, of: item) } == [100, 80, 200, 120, 30])
    #expect(TransformRow.allCases.map(\.rawValue) == ["x", "y", "w", "h", "rotation"])
}
