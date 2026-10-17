// FlareJourneyTests+Scenes.swift: J16, scenes and layers in the sidebar
// (layers-files LF-1; docs/blueprints/flare/features/layers-files.md, Journey
// steps, step 1). On `-FlareSample bounce` (live services): New Scene adds
// "Scene 2"; a double-click renames it "Outro"; a drag puts Outro above
// Scene 1; selecting Scene 1's row selects it and brings back its layers;
// Ball's eye and lock hide and lock it; New Layer adds "Layer 1", renamed
// "Sky". Each edit is one ⌘Z: the journey undoes it, sees the state before,
// and redoes it with ⇧⌘Z. The dimmed rows wait on SuiteUI #146 (the Model's
// layerRowIsDimmed is proven by FlareSidebarHelpTests), and removing a scene
// waits on the row menus (LF-2). The sidebar is read by its row titles top
// first, section headers left out. One shot per step, `flare-scenes-<step>`.
import XCTest

final class FlareScenesJourneys: XCTestCase {
    @MainActor func testScenesAddRenameReorderRemove() {
        let flare = Journey("Flare", self, arguments: ["-FlareSample", "bounce"])
        XCTAssert(flare.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let sidebar = flare.element("suite.sidebar")
        XCTAssert(sidebar.waitForExistence(timeout: 10), "the window has no sidebar")
        expectSidebar(["Scene 1", "Ball", "Shadow", "Background"], flare)
        flare.shot("scenes-0-bounce")

        // 1. New Scene: Scene 2 under Scene 1, selected, with no layers.
        let newScene = sidebar.buttons["New Scene"]
        XCTAssert(newScene.waitForExistence(timeout: 5), "SCENES has no New Scene button")
        newScene.click()
        expectSidebar(["Scene 1", "Scene 2"], flare)
        expectOneStep(before: ["Scene 1", "Ball", "Shadow", "Background"], after: ["Scene 1", "Scene 2"], flare)
        flare.shot("scenes-1-added")

        // 2. Double-click Scene 2, type Outro, Return.
        text("Scene 2", in: sidebar).doubleClick()
        let field = sidebar.textFields.firstMatch
        XCTAssert(field.waitForExistence(timeout: 5), "double-clicking Scene 2 opened no rename field")
        flare.press(character: "a", .command)
        field.typeText("Outro")
        flare.press(.return)
        expectSidebar(["Scene 1", "Outro"], flare)
        expectOneStep(before: ["Scene 1", "Scene 2"], after: ["Scene 1", "Outro"], flare)
        flare.shot("scenes-2-renamed")

        // 3. Drag Outro above Scene 1.
        let scene1 = row("Scene 1", flare)
        row("Outro", flare).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.6, thenDragTo: scene1.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)))
        expectSidebar(["Outro", "Scene 1"], flare)
        expectOneStep(before: ["Scene 1", "Outro"], after: ["Outro", "Scene 1"], flare)
        flare.shot("scenes-3-reordered")

        // 4. Select Scene 1: its row reads selected and its layers are back.
        text("Scene 1", in: sidebar).click()
        XCTAssert(waitFor { self.row("Scene 1", flare).isSelected }, "Scene 1's row isn't selected")
        expectSidebar(["Outro", "Scene 1", "Ball", "Shadow", "Background"], flare)
        flare.shot("scenes-4-selected")

        // 5. Ball's eye, then its lock: each flips its toggle and is one step.
        for (flag, on, off) in [("visible", "Hide Layer", "Show Layer"), ("locked", "Lock Layer", "Unlock Layer")] {
            let toggle = flare.element("suite.sidebar.ball.\(flag)")
            XCTAssert(toggle.waitForExistence(timeout: 5), "Ball has no \(flag) toggle")
            XCTAssert(toggle.label == on, "Ball's \(flag) toggle reads \(toggle.label), not \(on)")
            toggle.click()
            XCTAssert(waitFor { toggle.label == off }, "Ball's \(flag) toggle reads \(toggle.label) after a click")
            flare.press(character: "z", .command)
            XCTAssert(waitFor { toggle.label == on }, "⌘Z left Ball's \(flag) toggle at \(toggle.label)")
            flare.press(character: "z", [.command, .shift])
            XCTAssert(waitFor { toggle.label == off }, "⇧⌘Z left Ball's \(flag) toggle at \(toggle.label)")
        }
        flare.shot("scenes-5-ball-hidden-locked")

        // 6. New Layer adds Layer 1 on top; rename it Sky.
        let layers = ["Outro", "Scene 1", "Ball", "Shadow", "Background"]
        let newLayer = sidebar.buttons["New Layer"]
        XCTAssert(newLayer.waitForExistence(timeout: 5), "LAYERS has no New Layer button")
        newLayer.click()
        let added = ["Outro", "Scene 1", "Layer 1", "Ball", "Shadow", "Background"]
        expectSidebar(added, flare)
        expectOneStep(before: layers, after: added, flare)
        text("Layer 1", in: sidebar).doubleClick()
        let layerField = sidebar.textFields.firstMatch
        XCTAssert(layerField.waitForExistence(timeout: 5), "double-clicking Layer 1 opened no rename field")
        flare.press(character: "a", .command)
        layerField.typeText("Sky")
        flare.press(.return)
        let renamed = ["Outro", "Scene 1", "Sky", "Ball", "Shadow", "Background"]
        expectSidebar(renamed, flare)
        expectOneStep(before: added, after: renamed, flare)
        flare.shot("scenes-6-layer-renamed")
    }

    // MARK: - Helpers

    /// The first element in the sidebar whose label or value is `title`.
    @MainActor private func text(_ title: String, in root: XCUIElement) -> XCUIElement {
        root.descendants(matching: .any).matching(NSPredicate(format: "label == %@ OR value == %@", title, title)).firstMatch
    }

    /// The sidebar row (outline row, else cell) holding `title`.
    @MainActor private func row(_ title: String, _ flare: Journey) -> XCUIElement {
        let sidebar = flare.element("suite.sidebar")
        let match = NSPredicate(format: "label == %@ OR value == %@", title, title)
        let outline = sidebar.outlineRows.containing(match).firstMatch
        return outline.exists ? outline : sidebar.cells.containing(match).firstMatch
    }

    /// The sidebar's row titles, top first (the section headers left out).
    @MainActor private func sidebarTitles(_ flare: Journey) -> [String] {
        let texts = flare.element("suite.sidebar").staticTexts.allElementsBoundByIndex
        var seen = Set<String>()
        return texts.sorted { $0.frame.minY < $1.frame.minY }
            .map { $0.label.isEmpty ? ($0.value as? String ?? "") : $0.label }
            .filter { !$0.isEmpty && $0 != "Scenes" && $0 != "Layers" && seen.insert($0).inserted }
    }

    /// The sidebar lists exactly `titles`, top first, within ten seconds.
    @MainActor private func expectSidebar(_ titles: [String], _ flare: Journey) {
        XCTAssert(waitFor { self.sidebarTitles(flare) == titles }, "the sidebar reads \(sidebarTitles(flare)), not \(titles)")
    }

    /// ⌘Z brings back `before` and ⇧⌘Z `after`: the last edit was one undo step.
    @MainActor private func expectOneStep(before: [String], after: [String], _ flare: Journey) {
        flare.press(character: "z", .command)
        expectSidebar(before, flare)
        flare.press(character: "z", [.command, .shift])
        expectSidebar(after, flare)
    }

    @MainActor private func waitFor(_ condition: () -> Bool) -> Bool {
        for _ in 0..<100 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return condition()
    }
}
