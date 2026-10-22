// FlareJourneyTests+LottieOpen.swift (lottie-open LO-2 written, LO-5 turned on): opening a Lottie file and
// recolouring it, as a person does. The packet's journey steps:
// 1. Choose File > Open and pick bounce.json: the canvas shows the ball and the floor, the window reads "Untitled".
// 2. Play: the ball moves on the frames it moved on in the file.
// 3. Select the ball and pick a new fill colour: the canvas shows it; Undo takes it back, Redo puts it back.
// 4. Open precomp.json: a note above the stage names the precomp and the image left out; dismiss it.
// 5. Save: the panel asks for a new .flare file, and bounce.json's bytes are unchanged.
// 6. Export Lottie: the file holds the same keyframe count and the new colour.
// It skips until LO-5, when the open (LO-3) and its window wiring (LO-4) are on dev.
import XCTest

final class FlareLottieOpenJourneyTests: XCTestCase {
    static let arguments = ["-FlareServices", "live", "-SuiteWindowSize", "1024x768"]

    @MainActor func testOpenAndRecolour() throws {
        throw XCTSkip("waits on LO-5")
    }
}
