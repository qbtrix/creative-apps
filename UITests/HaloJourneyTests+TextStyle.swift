// HaloJourneyTests+TextStyle.swift (text-style TS-4, HJ-TS): Halo's title
// card journey. Add a text layer, type two lines, pick a family and Bold,
// tracking 50, centre; scrub and render a frame; the viewer and the render
// show the same two lines. Skipped by name until TS-10 draws the style
// through the kernel's layout; TS-4 only shows the shared text style rows
// (`suite.text.*`) in the TEXT section, disabled with "Text styles aren't
// connected in this window yet.".
import XCTest

final class HaloTextStyleJourneyTests: XCTestCase {
    @MainActor func testTitleCard() throws {
        throw XCTSkip("HJ-TS waits on TS-10: the text style rows show in Halo's TEXT section but don't act yet")
    }
}
