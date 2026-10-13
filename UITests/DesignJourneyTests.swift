// DesignJourneyTests.swift: Design driven like a person would, with a
// whole-window screenshot after every step (see Journey.swift). Each test is
// one journey; grow them as Design's features land, and replace the skipped
// test with the real journey when its issue is built. Design's window is an
// editor shell, so it is found by its tool rail and panel, and the buttons by
// the whole window.
import XCTest

final class DesignJourneyTests: XCTestCase {
    @MainActor func testLaunchShowsWindowShell() {
        Journey("Design", self).expectEditorShell()
    }

    @MainActor func testNewFileAndEveryTool() {
        let design = Journey("Design", self)
        design.click("New File", in: .window, step: "new-file")
        design.clickEachTool()
    }

    @MainActor func testEveryMenuOpens() {
        let design = Journey("Design", self)
        design.app.typeKey("n", modifierFlags: .command)
        design.openEachMenu()
    }

    @MainActor func testDrawShapesAddTextAndSave() throws {
        throw XCTSkip("journey arrives with #198 (draw), #199 (text) and #202 (save)")
    }
}
