// DesignJourneyTests.swift: Design driven like a person would, with a
// whole-window screenshot after every step (see Journey.swift). Design is an
// EditorShell window. The core journey draws a frame (crossing the page's top
// edge, so its handles show past it), a rectangle and an ellipse, moves and
// resizes the ellipse, checks the tool rail and the status line's tool are back
// on Move after each draw and after the text placement (#278), so the move and
// the press on the committed text select and move rather than draw again; checks Layers still marks the current page while the
// ellipse is selected, finds Add Page and Delete Page (`design.page.add`,
// `design.page.delete`) by the pages with Delete Page disabled on the one
// page, hides a layer from its row's eye and undoes that,
// places and types text (shot while typing, when the editor
// draws at full size, and once committed, with a small box's corner handles
// outside it), undoes and redoes, saves with -DesignSaveTo (no panel), then
// relaunches with -DesignOpenFile and checks the saved file reopens. The menu
// journey checks each menu really opens, and adds a page from the Page menu.
// The align journey draws a rectangle, centers it from the inspector's Align
// row and moves it to the top from Object > Align, one undo step each.
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

    @MainActor func testAlignALayer() {
        let design = Journey("Design", self)
        design.app.typeKey("n", modifierFlags: .command)
        XCTAssert(design.element("suite.canvas").waitForExistence(timeout: 10), "New File showed no canvas")
        design.element("suite.tools").buttons["Rectangle"].click()
        design.drag(on: "suite.canvas", from: CGVector(dx: 0.15, dy: 0.3), to: CGVector(dx: 0.3, dy: 0.45), step: "align-drew")
        XCTAssert(design.app.buttons["Undo Add Rectangle"].waitForExistence(timeout: 5), "drawing made no undo step")
        design.click("Align Center", in: .window, step: "align-centered")
        XCTAssert(design.app.buttons["Undo Align Center"].waitForExistence(timeout: 5), "Align Center made no undo step")
        XCTAssertFalse(design.app.windows.firstMatch.buttons["Align Center"].isEnabled, "Align Center stayed on once centered")
        design.app.menuBars.firstMatch.menuBarItems["Object"].click()
        design.app.menuItems["Align"].click()
        design.app.menuItems["Align Top"].click()
        XCTAssert(design.app.buttons["Undo Align Top"].waitForExistence(timeout: 5), "Object > Align > Align Top made no undo step")
        design.shot("align-top")
        design.click("Undo Align Top", in: .window, step: "align-undone")
        XCTAssert(design.app.buttons["Undo Align Center"].waitForExistence(timeout: 5), "Undo didn't undo Align Top alone")
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
        expectMove(design, after: "drawing a frame")
        tools["Rectangle"].click()
        design.drag(on: "suite.canvas", from: CGVector(dx: 0.15, dy: 0.15), to: CGVector(dx: 0.3, dy: 0.3), step: "drew-rectangle")
        XCTAssert(design.app.buttons["Undo Add Rectangle"].waitForExistence(timeout: 5), "drawing a rectangle made no undo step")
        expectMove(design, after: "drawing a rectangle")
        tools["Ellipse"].click()
        design.drag(on: "suite.canvas", from: CGVector(dx: 0.55, dy: 0.2), to: CGVector(dx: 0.75, dy: 0.45), step: "drew-ellipse")
        XCTAssert(design.app.buttons["Undo Add Ellipse"].waitForExistence(timeout: 5), "drawing an ellipse made no undo step")
        expectMove(design, after: "drawing an ellipse")

        // No click on Move: the draw left it picked, so this press grabs the ellipse's middle
        // and drags it down instead of drawing a second ellipse: it now spans (0.55, 0.475)-(0.75, 0.725).
        design.drag(on: "suite.canvas", from: CGVector(dx: 0.65, dy: 0.325), to: CGVector(dx: 0.65, dy: 0.6), step: "moved")
        XCTAssert(design.app.buttons["Undo Move"].waitForExistence(timeout: 5), "the press after a draw didn't move the ellipse")
        XCTAssertFalse(design.app.buttons["Undo Add Ellipse"].exists, "the press after a draw drew another ellipse")
        // Its bottom-right handle sits on that corner.
        design.drag(on: "suite.canvas", from: CGVector(dx: 0.75, dy: 0.725), to: CGVector(dx: 0.85, dy: 0.8), step: "resized")
        XCTAssert(design.app.buttons["Undo Resize"].waitForExistence(timeout: 5), "the handle drag didn't resize")
        design.shot("inspector")
        // Shift-click the rectangle: it joins the ellipse in the selection, and the inspector says so (#413).
        XCUIElement.perform(withKeyModifiers: .shift) {
            design.drag(on: "suite.canvas", from: CGVector(dx: 0.2, dy: 0.2), to: CGVector(dx: 0.2, dy: 0.2))
        }
        let both = design.app.descendants(matching: .any).matching(NSPredicate(format: "label == %@ OR value == %@", "2 Layers", "2 Layers")).firstMatch
        XCTAssert(both.waitForExistence(timeout: 5), "Shift-click didn't add the rectangle to the selection")
        design.shot("multi-select")
        // With the ellipse holding the selection, the Layers tab still checks the current page.
        tab("Layers", in: design)
        XCTAssert(design.element("design.current-page").waitForExistence(timeout: 5), "Layers lost the current page's mark")
        let window = design.app.windows.firstMatch
        XCTAssert(window.buttons["Delete Page"].waitForExistence(timeout: 3), "no Delete Page button by the pages:\n\(window.debugDescription)")
        // The page row's commands: Add Page runs; with one page, Delete Page is disabled (its tooltip says why).
        let addPage = window.buttons["design.page.add"], deletePage = window.buttons["design.page.delete"]
        XCTAssert(addPage.exists && addPage.label == "Add Page" && addPage.isEnabled, "no enabled Add Page by the pages")
        XCTAssert(deletePage.exists && deletePage.label == "Delete Page", "no Delete Page identified design.page.delete")
        XCTAssertFalse(deletePage.isEnabled, "Delete Page is enabled with one page")
        design.shot("layers")
        // A row's eye hides that layer as one undo step, and Undo shows it again.
        let eye = window.descendants(matching: .any).matching(NSPredicate(format: "label == %@", "Hide Layer")).firstMatch
        XCTAssert(eye.waitForExistence(timeout: 3), "no eye toggle on the layer rows:\n\(window.debugDescription)")
        eye.click()
        XCTAssert(design.app.buttons["Undo Hide Layer"].waitForExistence(timeout: 5), "the eye toggle made no undo step")
        design.shot("layer-hidden")
        design.click("Undo Hide Layer", in: .window, step: "layer-shown")
        tab("Properties", in: design)

        tools["Text"].click()
        design.drag(on: "suite.canvas", from: CGVector(dx: 0.2, dy: 0.75), to: CGVector(dx: 0.2, dy: 0.75), step: "text-placed")
        design.app.typeKey("a", modifierFlags: .command)
        design.app.typeText("Hello")
        design.shot("text-typed")
        design.app.typeText("\r")
        XCTAssert(design.app.buttons["Undo Add Text"].waitForExistence(timeout: 5), "typing text made no undo step")
        design.shot("text-committed")
        expectMove(design, after: "placing text")
        // The next press, just inside the small text box, moves it instead of placing more text.
        let canvas = design.element("suite.canvas")
        let text = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.75)).withOffset(CGVector(dx: 6, dy: 4))
        text.press(forDuration: 0.1, thenDragTo: text.withOffset(CGVector(dx: 40, dy: 0)))
        XCTAssert(design.app.buttons["Undo Move"].waitForExistence(timeout: 5), "the press after placing text didn't move it")
        XCTAssertFalse(design.element("design.text").exists, "the press after placing text started another text edit")
        design.shot("text-moved")
        design.click("Undo Move", in: .window, step: "text-move-undone")
        XCTAssert(design.app.buttons["Undo Add Text"].waitForExistence(timeout: 5), "undoing the text move lost Add Text")

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

    /// The tool rail shows Move as the picked tool and the status line names Move, checked for
    /// up to three seconds after `action`.
    @MainActor private func expectMove(_ design: Journey, after action: String) {
        let move = design.element("suite.tools").buttons["Move"]
        let status = design.element("design.status.tool")
        XCTAssert(status.waitForExistence(timeout: 5), "no tool in the status line (design.status.tool)")
        var picked = false
        for _ in 0..<10 {
            picked = move.isSelected && ((status.value as? String) == "Move" || status.label == "Move")
            if picked { break }
            Thread.sleep(forTimeInterval: 0.3)
        }
        XCTAssert(move.isSelected, "the tool rail doesn't show Move picked after \(action)")
        XCTAssert(picked, "the status line shows \(status.label) \(String(describing: status.value)), not Move, after \(action)")
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
