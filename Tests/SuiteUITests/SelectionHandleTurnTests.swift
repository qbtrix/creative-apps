// SelectionHandleTurnTests.swift: the turned selection box (transform-tools
// TT-3). The editor draws the box turned about its centre, and a drag on it
// maps each sample back into the box's own frame (TransformRules.local)
// before resizing, so a side handle grows the box along its own edge and the
// opposite edge stays put. At no turn the drag is exactly CM-4's. The tests
// that need the rules' bodies switch on once TT-5 lands (normalized(190) is
// -170 only then). No rendering. macOS only.
import Foundation
import SuiteKernel
import Testing

@testable import SuiteUI

/// The gallery page's box, in document pixels at zoom 1: centre (200, 140).
private let box = CGRect(x: 100, y: 80, width: 200, height: 120)
private let rulesBuilt = TransformRules.normalized(190) == -170

@Test func theDrawingTurnsTheBoxAboutItsCentre() {
    let turn = SelectionHandlesEditor.turn(90, rect: box, zoom: 1)
    // The right handle's centre (300, 140) lands below the centre, at (200, 240).
    let right = CGPoint(x: 300, y: 140).applying(turn)
    #expect(abs(right.x - 200) < 1e-9 && abs(right.y - 240) < 1e-9)
    let centre = CGPoint(x: 200, y: 140).applying(turn)
    #expect(abs(centre.x - 200) < 1e-9 && abs(centre.y - 140) < 1e-9)
    #expect(SelectionHandlesEditor.turn(0, rect: box, zoom: 1) == .identity)
    // At zoom 2 the centre is in view points: (400, 280).
    let doubled = CGPoint(x: 400, y: 280).applying(SelectionHandlesEditor.turn(45, rect: box, zoom: 2))
    #expect(abs(doubled.x - 400) < 1e-9 && abs(doubled.y - 280) < 1e-9)
}

@Test func anUnturnedDragIsUnchanged() {
    var drag = SelectionHandleDrag()
    let edit = drag.changed(rect: box, degrees: 0, zoom: 1, from: CGPoint(x: 300, y: 140), to: CGPoint(x: 340, y: 140),
                            shift: false)
    #expect(edit == .resize(CGRect(x: 100, y: 80, width: 240, height: 120)))
}

@Test(.enabled(if: rulesBuilt, "waits on TT-5's TransformRules.local and scaled"))
func aTurnedRightHandleGrowsTheBoxAlongItsOwnEdge() throws {
    var drag = SelectionHandleDrag()
    // Turned 90°, the right handle sits at (200, 240); 40 pt down is 40 along the box's own right edge.
    let edit = drag.changed(rect: box, degrees: 90, zoom: 1, from: CGPoint(x: 200, y: 240), to: CGPoint(x: 200, y: 280),
                            shift: false)
    guard case let .resize(grown)? = edit else {
        Issue.record("the turned right handle did not resize: \(String(describing: edit))")
        return
    }
    #expect(abs(grown.width - 240) < 1e-6 && abs(grown.height - 120) < 1e-6)
    // The left edge's middle, turned to (200, 40), stays put: the grown box's centre is 120 below it.
    #expect(abs(grown.midX - 200) < 1e-6 && abs(grown.midY - 160) < 1e-6)
    let ended = drag.ended()
    #expect(ended)
}

@Test(.enabled(if: rulesBuilt, "waits on TT-5's TransformRules.local"))
func theTurnedKnobStillTurns() throws {
    let kernel = Rect(minX: 100, minY: 80, maxX: 300, maxY: 200)
    let knob = try #require(SelectionHandles.marks(handles: BoxMath.handles(of: kernel, size: 8), zoom: 1)
        .first { $0.handle == .rotate }?.frame)
    // Turned 90°, the knob above the top edge sits right of the box.
    let at = CGPoint(x: knob.midX, y: knob.midY).applying(SelectionHandlesEditor.turn(90, rect: box, zoom: 1))
    var drag = SelectionHandleDrag()
    let edit = drag.changed(rect: box, degrees: 90, zoom: 1, from: at, to: CGPoint(x: 200, y: at.y + (at.x - 200)),
                            shift: false, knob: knob)
    guard case let .rotate(degrees)? = edit else {
        Issue.record("the turned knob did not turn: \(String(describing: edit))")
        return
    }
    #expect(abs(degrees - 90) < 1e-6)
}

@Test func theKnobReadsItsTurn() {
    #expect(SelectionHandlesEditor.knobValue(15) == "15 degrees")
    #expect(SelectionHandlesEditor.knobValue(-89.6) == "-90 degrees")
    #expect(SelectionHandlesEditor.knobValue(1) == "1 degree")
}
