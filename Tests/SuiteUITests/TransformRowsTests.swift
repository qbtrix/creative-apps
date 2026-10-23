// TransformRowsTests.swift: the inspector's transform rows (transform-tools
// TT-3). Each row edit asks for exactly one TransformIntent: a typed
// rotation one `.rotate` by the difference, X, Y, W and H one `.set` that
// keeps the rest of the box (a turned box's typed W or H keeps its left or
// top side on screen, as a handle drag does); a value that changes nothing or
// a size under 1 asks for none. With several turns ("Mixed") the row reads
// "Rotate By" and a typed value turns by itself, even the shown one. Flip Horizontal and Flip Vertical each ask for one `.flip`,
// and with `flipHelp` set both are disabled and say why; with no selection
// every row is disabled and says why; the flips draw the mirror symbols
// (FlipDirection.systemImage). No rendering. macOS only.
import AppKit
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
    #expect(wider == .set(TransformRules.scaled(item, sx: 1.2, sy: 1, about: .left), drag: "d"))
    let taller = TransformRows.intent(.h, to: 60, from: item, drag: nil)
    #expect(taller == .set(TransformRules.scaled(item, sx: 1, sy: 0.5, about: .top), drag: nil))
    let flat = TransformBox(box: Rect(minX: 100, minY: 80, maxX: 300, maxY: 200))
    let flatWider = TransformRows.intent(.w, to: 240, from: flat, drag: nil)
    #expect(flatWider == .set(TransformBox(box: Rect(minX: 100, minY: 80, maxX: 340, maxY: 200)), drag: nil))
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

/// The flips draw Apple's mirror symbols, which exist on this system, not the two-way arrows a move or
/// resize uses, so a first-time user reads them as mirroring (Design mac finish, transform DT-a).
@Test @MainActor func theFlipsDrawTheMirrorSymbols() {
    let actions = TransformRows.flips(selection: item, help: nil, flipHelp: nil) { _ in }
    #expect(actions.map(\.title) == ["Flip Horizontal", "Flip Vertical"])
    #expect(actions.map(\.systemImage) == [
        "arrow.left.and.right.righttriangle.left.righttriangle.right",
        "arrow.up.and.down.righttriangle.up.righttriangle.down",
    ])
    #expect(actions.allSatisfy { NSImage(systemSymbolName: $0.systemImage, accessibilityDescription: nil) != nil })
}

private func near(_ a: [Point], _ b: [Point]) -> Bool {
    a.count == b.count && zip(a, b).allSatisfy { abs($0.x - $1.x) < 1e-9 && abs($0.y - $1.y) < 1e-9 }
}

private func box(of intent: TransformIntent?) -> TransformBox? {
    if case let .set(t, _) = intent { return t }
    return nil
}

/// #4626: a 200 x 120 box at (100, 80) turned 90 degrees, typed W 240, keeps its visible left side, the
/// corners at (260, 40) and (260, 240); typed H keeps its top side. A handle drag keeps the same side.
@Test func aTurnedBoxsTypedSizeKeepsItsLeftOrTopSide() throws {
    let turned = TransformBox(box: Rect(minX: 100, minY: 80, maxX: 300, maxY: 200), degrees: 90)
    let before = TransformRules.corners(of: turned)
    #expect(near([before[0], before[3]], [Point(x: 260, y: 40), Point(x: 260, y: 240)]))
    let wider = try #require(box(of: TransformRows.intent(.w, to: 240, from: turned, drag: nil)))
    #expect(abs(wider.box.width - 240) < 1e-9 && wider.box.height == 120 && wider.degrees == 90)
    let after = TransformRules.corners(of: wider)
    #expect(near([after[0], after[3]], [before[0], before[3]]))
    let taller = try #require(box(of: TransformRows.intent(.h, to: 60, from: turned, drag: nil)))
    let top = TransformRules.corners(of: taller)
    #expect(near([top[0], top[1]], [before[0], before[1]]))
}

/// #4626: with several turns the union box reads 0; a typed value turns every item by itself, even 0
/// (the shown value), and a drag turns by the change since its last step, not from 0 again.
@Test func aMixedTurnTurnsByTheTypedValueEvenTheShownOne() {
    let union = TransformBox(box: Rect(minX: 60, minY: 60, maxX: 340, maxY: 240))
    #expect(TransformRows.intent(.rotation, to: 0, from: union, drag: nil, mixed: true) == .rotate(by: 0, drag: nil))
    #expect(TransformRows.intent(.rotation, to: 30, from: union, drag: nil, mixed: true) == .rotate(by: 30, drag: nil))
    #expect(TransformRows.intent(.rotation, to: 25, from: union, drag: "d", mixed: true, turned: 10)
        == .rotate(by: 15, drag: "d"))
    #expect(TransformRows.intent(.rotation, to: 0, from: union, drag: nil) == nil)
    #expect(TransformRows.intent(.rotation, to: 400, from: union, drag: nil, mixed: true) == nil)
}

@Test func aMixedRowSaysATypedTurnIsRelative() {
    #expect(TransformRows.rotationLabel(mixed: false) == "Rotation")
    #expect(TransformRows.rotationLabel(mixed: true) == "Rotate By")
    #expect(TransformRows.mixedHelp.contains("by that much more"))
}

/// #4629: the icon-only flips have a visible "Flip" in front; each keeps its full name as label and help.
@Test @MainActor func theFlipsHaveAVisibleNameAndKeepTheirFullNames() {
    #expect(TransformRows.flipLabel == "Flip")
    let actions = TransformRows.flips(selection: nil, help: nil, flipHelp: nil) { _ in }
    #expect(actions.map { InspectorAction.help($0, iconOnly: true) }
        == ["Flip Horizontal: \(TransformRows.noSelection)", "Flip Vertical: \(TransformRows.noSelection)"])
}
