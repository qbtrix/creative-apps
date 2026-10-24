// RotateKnobAccessibilityTests.swift: the selection box's rotate knob
// (`suite.handles.turn`) read from the window's accessibility tree, as
// ScrubAccessibilityTests reads the number fields (#5132). The knob is an
// adjustable slider named "Rotate" whose value is the box's turn: XCUI reads
// the number from AXValue and VoiceOver hears "90 degrees". Increment and
// decrement turn the box 1° each as one finished turn (onRotate, then onEnd);
// Shift makes the step 15°. The identifier stays. macOS only.
import AppKit
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor private final class TurnLog {
    var turns: [Double] = []
    var ends = 0
}

@MainActor @Test func theRotateKnobIsAnAdjustableSliderWithItsAngle() throws {
    let log = TurnLog()
    let window = axWindow(SelectionHandlesEditor(
        rect: CGRect(x: 60, y: 120, width: 200, height: 120), degrees: 90, zoom: 1,
        onResize: { _ in }, onRotate: { log.turns.append($0) }, onEnd: { log.ends += 1 }
    ).frame(width: 320, height: 400, alignment: .topLeading))
    defer { window.orderOut(nil) }
    let knob = try #require(axElement(in: window, role: .slider), "the rotate knob is no slider (#5147)")
    let node = knob as AnyObject
    #expect(node.accessibilityLabel?() == "Rotate")
    #expect(node.accessibilityIdentifier?() == "suite.handles.turn")
    #expect((knob.value(forKey: "accessibilityValue") as? NSNumber)?.doubleValue == 90, "XCUI reads no angle")
    #expect(knob.value(forKey: "accessibilityValueDescription") as? String == "90 degrees")
    #expect(node.accessibilityPerformIncrement?() == true)
    #expect(node.accessibilityPerformDecrement?() == true)
    #expect(log.turns == [1, -1] && log.ends == 2, "each step isn't one 1° turn: \(log.turns), \(log.ends) ends")
}

@Test func aShiftStepIsFifteenDegrees() {
    #expect(SelectionHandlesEditor.knobStep(.increment, shift: false) == 1)
    #expect(SelectionHandlesEditor.knobStep(.decrement, shift: false) == -1)
    #expect(SelectionHandlesEditor.knobStep(.increment, shift: true) == 15)
    #expect(SelectionHandlesEditor.knobStep(.decrement, shift: true) == -15)
}
