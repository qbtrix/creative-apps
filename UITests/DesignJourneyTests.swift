// DesignJourneyTests.swift: Design driven like a person would, with a
// whole-window screenshot after every step (see Journey.swift). Design is an
// EditorShell window. The core journey draws a frame (crossing the page's top
// edge, so its handles show past it), a rectangle and an ellipse, moves and
// resizes the ellipse, checks Layers still marks the current page while the
// ellipse is selected, places and types text (shot while typing, when the editor
// draws at full size, and once committed, with a small box's corner handles
// outside it), undoes and redoes, saves with -DesignSaveTo (no panel), then
// relaunches with -DesignOpenFile and checks the saved file reopens. The menu
// journey checks each menu really opens, and adds a page from the Page menu.
import XCTest

final class DesignJourneyTests: XCTestCase {
    @MainActor func testLaunchShowsWindowShell() {
        Journey("Design", self).expectEditorShell()
    }

    @MainActor func testNewFileAndEveryTool() {
        let design = Journey("Design", self)
        design.app.typeKey("n", modifierFlags: .command)
        design.shot("new-file")
        design.clickEachTool()
    }

    @MainActor func testEveryMenuOpens() {
        let design = Journey("Design", self)
        design.app.typeKey("n", modifierFlags: .command)
        design.openEachMenu(expecting: ["Page": "Add Page"])
        design.app.menuBars.firstMatch.menuBarItems["Page"].click()
        design.app.menuItems["Add Page"].click()
        XCTAssert(design.app.buttons["Undo Add Page"].waitForExistence(timeout: 5), "Page > Add Page added no page")
        design.shot("added-page")
    }

    @MainActor func testDrawShapesAddTextAndSave() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "design-journey-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let file = folder.appending(path: "journey.design")
        let design = Journey("Design", self, arguments: ["-DesignSaveTo", file.path])
        design.app.typeKey("n", modifierFlags: .command)
        XCTAssert(design.element("suite.canvas").waitForExistence(timeout: 10), "New File showed no canvas")
        design.shot("drawing-new-file")
        let tools = design.element("suite.tools").buttons

        tools["Frame"].click()
        design.drag(on: "suite.canvas", from: CGVector(dx: 0.1, dy: 0.1), to: CGVector(dx: 0.45, dy: 0.5), step: "drew-frame")
        XCTAssert(design.app.buttons["Undo Add Frame"].waitForExistence(timeout: 5), "drawing a frame made no undo step")
        tools["Rectangle"].click()
        design.drag(on: "suite.canvas", from: CGVector(dx: 0.15, dy: 0.15), to: CGVector(dx: 0.3, dy: 0.3), step: "drew-rectangle")
        tools["Ellipse"].click()
        design.drag(on: "suite.canvas", from: CGVector(dx: 0.55, dy: 0.2), to: CGVector(dx: 0.75, dy: 0.45), step: "drew-ellipse")
        XCTAssert(design.app.buttons["Undo Add Ellipse"].waitForExistence(timeout: 5), "drawing an ellipse made no undo step")

        tools["Move"].click()
        // Grab the ellipse's middle and drag it down: it now spans (0.55, 0.475)-(0.75, 0.725).
        design.drag(on: "suite.canvas", from: CGVector(dx: 0.65, dy: 0.325), to: CGVector(dx: 0.65, dy: 0.6), step: "moved")
        XCTAssert(design.app.buttons["Undo Move"].waitForExistence(timeout: 5), "the move made no undo step")
        // Its bottom-right handle sits on that corner.
        design.drag(on: "suite.canvas", from: CGVector(dx: 0.75, dy: 0.725), to: CGVector(dx: 0.85, dy: 0.8), step: "resized")
        XCTAssert(design.app.buttons["Undo Resize"].waitForExistence(timeout: 5), "the handle drag didn't resize")
        design.shot("inspector")
        // With the ellipse holding the selection, the Layers tab still checks the current page.
        tab("Layers", in: design)
        XCTAssert(design.element("design.current-page").waitForExistence(timeout: 5), "Layers lost the current page's mark")
        let window = design.app.windows.firstMatch
        XCTAssert(window.buttons["Delete Page"].waitForExistence(timeout: 3), "no Delete Page button by the pages:\n\(window.debugDescription)")
        design.shot("layers")
        tab("Properties", in: design)

        tools["Text"].click()
        design.drag(on: "suite.canvas", from: CGVector(dx: 0.2, dy: 0.75), to: CGVector(dx: 0.2, dy: 0.75), step: "text-placed")
        design.app.typeKey("a", modifierFlags: .command)
        design.app.typeText("Hello")
        design.shot("text-typed")
        design.app.typeText("\r")
        XCTAssert(design.app.buttons["Undo Add Text"].waitForExistence(timeout: 5), "typing text made no undo step")
        design.shot("text-committed")

        design.click("Undo Add Text", in: .window, step: "undone")
        XCTAssert(design.app.buttons["Redo Add Text"].waitForExistence(timeout: 5), "Undo didn't undo the text")
        design.click("Redo Add Text", in: .window, step: "redone")

        design.app.typeKey("s", modifierFlags: .command)
        XCTAssert(Self.waitForFile(file), "Save wrote no file")
        let data = try Data(contentsOf: file)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(json?["version"] as? Int, 1, "the saved file has no version 1")
        XCTAssert(String(decoding: data, as: UTF8.self).contains("Hello"), "the saved file lost the text")
        design.shot("saved")
        design.app.terminate()

        let reopened = Journey("Design", self, arguments: ["-DesignOpenFile", file.path])
        XCTAssert(reopened.app.windows["journey.design"].waitForExistence(timeout: 30), "journey.design didn't reopen")
        reopened.shot("reopened")
    }

    /// Clicks the panel tab titled `title` (a segment, whatever role the system gives it).
    @MainActor private func tab(_ title: String, in design: Journey) {
        let segment = design.app.windows.firstMatch.descendants(matching: .any)
            .matching(NSPredicate(format: "label == %@", title)).firstMatch
        XCTAssert(segment.waitForExistence(timeout: 5), "no \(title) tab")
        segment.click()
    }

    /// Waits up to 15 seconds for `url` to exist.
    private static func waitForFile(_ url: URL) -> Bool {
        for _ in 0..<30 {
            if FileManager.default.fileExists(atPath: url.path) { return true }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return false
    }
}
