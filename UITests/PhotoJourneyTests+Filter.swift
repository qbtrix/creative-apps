// PhotoJourneyTests+Filter.swift (adjust-everywhere AJ-3, AJ-4): the filter
// and look journeys, skipped until the workspace adopts AdjustTarget and the
// window opens FilterSheet (AJ-8). Both open beach.png (800 x 600).
import XCTest

final class PhotoFilterJourneyTests: XCTestCase {
    /// Marquee, Filter > Blur > Gaussian Blur…, Radius (`suite.filter.slider.radius`), OK (`suite.filter.ok`):
    /// only the selection blurs, as one undo step ("Undo Gaussian Blur").
    @MainActor func testGaussianBlurInsideSelection() throws {
        throw XCTSkip("waits on AJ-8")
    }

    /// B&W in the Looks grid (`suite.looks.look.bw`), Save Look… (`suite.looks.save`), a name in `suite.looks.name`,
    /// Save (`suite.looks.name.save`): the new look follows the six built-ins, and Save As writes the picture.
    @MainActor func testApplyAndSaveLook() throws {
        throw XCTSkip("waits on AJ-8")
    }
}
