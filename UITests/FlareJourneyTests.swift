// FlareJourneyTests.swift: Flare driven like a person would, with a
// whole-window screenshot after every step (see Journey.swift). Each test is
// one journey; grow them as Flare's features land, and replace the skipped
// test with the real journey when its issue is built.
import XCTest

final class FlareJourneyTests: XCTestCase {
    @MainActor func testLaunchShowsWindowShell() {
        Journey("Flare", self).expectWindowShell()
    }

    @MainActor func testNewAnimationAndEveryTool() {
        let flare = Journey("Flare", self)
        flare.click("New Animation", step: "new-animation")
        flare.clickEachTool()
    }

    @MainActor func testEveryMenuOpens() {
        let flare = Journey("Flare", self)
        flare.click("New Animation")
        flare.openEachMenu()
    }

    @MainActor func testDrawKeyAndSave() throws {
        throw XCTSkip("journey arrives with #203 (draw), #204 (key) and #205 (save)")
    }
}
