// SuiteJourneyTests+Chrome.swift: SJ4, EC-10 (packet
// docs/blueprints/suiteui/features/editor-chrome.md, Journey step 1). On the
// gallery's `editor` page the floating palette holds tools a, b and c, with c
// disabled ("Tool C needs a layer to act on."). A click on tool b logs
// `tool b` into `suite.gallery.log`; then the first tool's key, A, pressed
// while focus is in the palette, picks it through SuiteToolPicking (EC-8) and
// logs `tool a`. Each tool's `isSelected` follows the pick. Tool c's
// `suite.controls` entry is disabled with that reason, and a click on it or
// its key C changes neither the log nor the selection.
import XCTest

extension SuiteJourneyTests {
    /// SJ4: a click and a key each pick a tool; the disabled tool explains itself and takes neither.
    @MainActor func testToolPaletteSelectsAndExplains() throws {
        let gallery = Journey("Library", self, name: "suiteui", arguments: ["-SuiteGallery", "editor", "-SuitePerfProbe"])
        XCTAssert(gallery.element("suite.gallery.editor").waitForExistence(timeout: 30), "no gallery page editor")
        let log = gallery.element("suite.gallery.log")
        XCTAssert(log.waitForExistence(timeout: 10), "no suite.gallery.log")
        let a = chromeTool("a", gallery), b = chromeTool("b", gallery), c = chromeTool("c", gallery)
        XCTAssert(a.isSelected && !b.isSelected, "tool a isn't the one selected on open")
        gallery.shot("editor-palette-open")

        // 1. Click tool b: the log says so and the selection moves.
        b.click()
        XCTAssert(chromeWait { self.chromeLines(log).last == "tool b" }, "clicking tool b logged \(chromeLines(log).suffix(2))")
        XCTAssert(chromeWait { b.isSelected && !a.isSelected }, "isSelected didn't follow the click to tool b")
        gallery.shot("editor-palette-tool-b")

        // 2. The first tool's key, with focus in the palette after the click, picks tool a.
        gallery.press(character: "a")
        XCTAssert(chromeWait { self.chromeLines(log).last == "tool a" },
                  "the key A didn't pick tool a (focus in the palette?): \(chromeLines(log).suffix(2))")
        XCTAssert(chromeWait { a.isSelected && !b.isSelected }, "isSelected didn't follow the key to tool a")
        gallery.shot("editor-palette-key-a")

        // 3. Tool c is disabled and says why in suite.controls.
        XCTAssertFalse(c.isEnabled, "tool c is enabled")
        let entry = gallery.controls()?.controls.first { $0.id == "suite.gallery.editor.tool.c" }
        XCTAssertEqual(entry?.enabled, false, "suite.controls has tool c enabled or missing")
        XCTAssertEqual(entry?.reason, "Tool C needs a layer to act on.", "tool c's reason")

        // 4. Neither a click on c nor its key changes the log or the selection.
        let before = chromeLines(log)
        c.click()
        gallery.press(character: "c")
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(chromeLines(log), before, "the disabled tool c changed the log")
        XCTAssert(a.isSelected && !c.isSelected, "the disabled tool c took the selection")
        gallery.shot("editor-palette-disabled-c")
        gallery.app.terminate()
    }

    /// The palette's tool `id`, `suite.gallery.editor.tool.<id>`.
    @MainActor private func chromeTool(_ id: String, _ gallery: Journey) -> XCUIElement {
        let tool = gallery.element("suite.gallery.editor.tool.\(id)")
        XCTAssert(tool.waitForExistence(timeout: 10), "no suite.gallery.editor.tool.\(id)")
        return tool
    }

    /// The log's lines: its value when it has one, else its label.
    @MainActor private func chromeLines(_ log: XCUIElement) -> [String] {
        let value = log.value as? String ?? ""
        return (value.isEmpty ? log.label : value).split(separator: "\n").map(String.init)
    }

    /// Whether `condition` holds within about three seconds.
    @MainActor private func chromeWait(_ condition: () -> Bool) -> Bool {
        for _ in 0..<15 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }
}
