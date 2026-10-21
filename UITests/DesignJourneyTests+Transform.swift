// DesignJourneyTests+Transform.swift: J-DT, turn and mirror a layer on live services
// (docs/blueprints/design/features/transform.md, Journey steps): the rotate knob with
// Shift lands on 15° and Rotation (`design.inspector.rotation`) reads it; the right
// handle grows along the turn; Object > Flip Horizontal mirrors in place; 0 in Rotation
// stands it up, one step per gesture; the SVG writes the turn. Written in DT-2 on the
// stubs, skipped until DT-7.
import XCTest

final class DesignTransformJourneyTests: XCTestCase {
    static let arguments = ["-DesignServices", "live", "-SuiteWindowSize", "1024x768"]

    /// J-DT steps 1 to 5: the knob turns, the handle grows along the turn, Flip mirrors, 0 stands it up, SVG says so.
    @MainActor func testRotateAndFlip() throws { throw XCTSkip("waits on DT-7") }
}
