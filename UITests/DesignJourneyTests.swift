// DesignJourneyTests.swift: Design driven like a person would, with a
// whole-window screenshot after every step (see Journey.swift). Each test is
// one journey; grow them as Design's features land, and replace the skipped
// test with the real journey when its issue is built.
import XCTest

final class DesignJourneyTests: XCTestCase {
    @MainActor func testLaunchShowsWindowShell() {
        Journey("Design", self).expectWindowShell()
    }

    @MainActor func testNewFileAndEveryTool() {
        let design = Journey("Design", self)
        design.click("New File", step: "new-file")
        design.clickEachTool()
    }

    @MainActor func testEveryMenuOpens() {
        let design = Journey("Design", self)
        design.click("New File")
        design.openEachMenu()
    }

    @MainActor func testDrawShapesAddTextAndSave() throws {
        throw XCTSkip("journey arrives with #198 (draw), #199 (text) and #202 (save)")
    }
}
