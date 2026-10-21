// DesignJourneyTests+Eyedropper.swift (eyedropper DY-2 written, DY-7 turned on): picking a fill and a stroke
// from one shape onto another, as a person does. The packet's journey steps:
// 1. Select a white rectangle, click the palette's `design.tool.eyedropper`: it is selected, the status line's
//    tool reads Eyedropper; the loupe follows the pointer.
// 2. Click a red ellipse: the rectangle's fill turns red, one "Fill" step (the top bar's Undo names it).
// 3. Option-click a blue text: the rectangle's stroke turns blue.
// 4. Click the palette's `design.tool.move`: it is selected, the status line reads Move, the rectangle still selected.
// 5. Keyboard parity: press I, the Eyedropper is selected; press V, Move is back.
// It skips until DY-7, when the adapter's bodies (DY-5) and the loupe (DY-3) are on dev.
import XCTest

final class DesignEyedropperJourneyTests: XCTestCase {
    @MainActor func testPickFillFromShape() throws {
        throw XCTSkip("waits on DY-7")
    }
}
