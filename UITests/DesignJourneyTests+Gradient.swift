// DesignJourneyTests+Gradient.swift (gradient-fill DG-6 written, DG-7 turned on): giving shapes and text a
// gradient, as a person does. The packet's journey steps:
// 1. Select the background rectangle and pick Linear in the Fill section: the canvas shows the gradient.
// 2. Type 90 in the angle field: the gradient runs top to bottom.
// 3. Click the middle of the stop bar and pick a colour: a third stop; Undo twice takes it and the angle back.
// 4. Select the text and pick Radial: its letters take the gradient.
// 5. Export SVG: the file holds a linearGradient and a radialGradient.
// It skips until DG-7, when the fill commands (DG-4) and the SVG gradients (DG-5) are on dev.
import XCTest

final class DesignGradientJourneyTests: XCTestCase {
    static let arguments = ["-DesignServices", "live", "-SuiteWindowSize", "1024x768"]

    @MainActor func testGradientFillAngle() throws {
        throw XCTSkip("waits on DG-7")
    }
}
