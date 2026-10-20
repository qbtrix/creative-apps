// DesignJourneyTests+Layers.swift: the Layers steps Design's journeys share.
// A document opens with every layer row collapsed (DesignWorkspace.load clears
// the expanded rows), so on `cards` only Desktop's row shows until its
// disclosure opens; a journey that clicks A, Title or Hidden opens Desktop
// first (#2456, #2457). The disclosure is the triangle in the parent's
// outline row, found by the row's `design.layer.<id>`; clicking it changes
// no selection. A row is clicked in its blank space, between the name and the
// Hide toggle: a click on the name itself doesn't select the row (#2496).
// DesignLayersJourneyTests holds the Layers panel's own journeys: J12 renames,
// reorders and nests layers from their rows and sends one to the back, each
// one undo step (L-5, #1986), and a group row's eye hides the group (L-6,
// #2758). A group's row reads as one checkbox (#2410), so its eye is clicked
// at the toggle column a child row's own eye shows: a toggle sits at the same
// x in every row (#53).
import XCTest

extension Journey {
    /// Opens the Layers row `identifier` (a frame or group) when it is collapsed, so its children's rows show.
    func expandDesignLayer(_ identifier: String) {
        let row = element("suite.sidebar").outlineRows.containing(.any, identifier: identifier).firstMatch
        XCTAssert(row.waitForExistence(timeout: 5), "no \(identifier) row in Layers")
        let triangle = row.disclosureTriangles.firstMatch
        XCTAssert(triangle.waitForExistence(timeout: 5), "the Layers row \(identifier) has no disclosure triangle")
        guard (triangle.value as? Int) != 1 else { return }
        triangle.click()
        let opened = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == 1"), object: triangle)
        XCTAssertEqual(XCTWaiter.wait(for: [opened], timeout: 5), .completed, "clicking \(identifier)'s disclosure didn't open it")
    }

    /// Clicks the Layers row `identifier` midway between its name and its Hide toggle (#2496),
    /// holding `modifiers`; a row with no name or toggle in reach is clicked at 60% of its width.
    func clickDesignLayer(_ identifier: String, modifiers: XCUIElement.KeyModifierFlags = []) {
        let layer = element("suite.sidebar").descendants(matching: .any)[identifier].firstMatch
        XCTAssert(layer.waitForExistence(timeout: 5), "no \(identifier) row in Layers")
        let row = layer.frame, title = layer.staticTexts.firstMatch, toggle = layer.checkBoxes.firstMatch
        var dx = 0.6
        if row.width > 0, title.exists, toggle.exists, title.frame.maxX < toggle.frame.minX {
            dx = Double((title.frame.maxX + toggle.frame.minX) / 2 - row.minX) / Double(row.width)
        }
        let point = layer.coordinate(withNormalizedOffset: CGVector(dx: dx, dy: 0.5))
        XCUIElement.perform(withKeyModifiers: modifiers) { point.click() }
    }

    /// The first element inside `row` whose label is `label`.
    func designLayerToggle(_ row: XCUIElement, _ label: String) -> XCUIElement {
        row.descendants(matching: .any).matching(NSPredicate(format: "label == %@", label)).firstMatch
    }
}

/// The Layers panel's journeys (layers-panel): J12 (L-5) and the group row's eye (L-6).
final class DesignLayersJourneyTests: XCTestCase {
    /// `cards`' Desktop frame (node-1), the group Pair (node-6) in it, and Pair's ellipses E1 and E2.
    static let desktopRow = "design.layer.node-1", pairRow = "design.layer.node-6"
    static let childRows = ["design.layer.node-7", "design.layer.node-8"]
    /// `cards`' A, B, C and Title, all in Desktop; `two-pages` adds the page Mobile.
    static let aRow = "design.layer.node-2", bRow = "design.layer.node-3", cRow = "design.layer.node-4"
    static let titleRow = "design.layer.node-5"

    /// J12 (L-5, #1986) on `two-pages`: A renamed Avatar from its row ("Rename Layer"), an empty
    /// rename refused with nothing recorded, B dragged above C and Title into Pair ("Move Layer"),
    /// and B sent to the back from Object > Arrange ("Send to Back"). Each step is one undo step:
    /// one ⌘Z takes it back whole and ⇧⌘Z puts it back. The group-eye step is L-6's test.
    @MainActor func testLayersRenameReorderNest() {
        let design = Journey("Design", self, arguments: ["-DesignFixture", "two-pages"])
        XCTAssert(design.element(Self.desktopRow).waitForExistence(timeout: 30), "two-pages showed no Desktop row")
        let undo = design.element("design.bar.undo")
        design.expandDesignLayer(Self.desktopRow)
        let (a, b, c) = (design.element(Self.aRow), design.element(Self.bRow), design.element(Self.cRow))
        XCTAssert(a.waitForExistence(timeout: 5), "opening Desktop showed no A row")

        // 1. Double-click A's name, Avatar, Return: one Rename Layer step.
        a.staticTexts["A"].firstMatch.doubleClick()
        let field = design.element("suite.sidebar.node-2.rename")
        XCTAssert(field.waitForExistence(timeout: 5), "double-clicking A's name opened no rename field")
        design.press(character: "a", .command)
        design.app.typeText("Avatar")
        design.press(.return)
        XCTAssert(Self.waitUntil { a.staticTexts["Avatar"].exists }, "A's row doesn't read Avatar after the rename")
        XCTAssert(Self.waitUntil { undo.label == "Undo Rename Layer" }, "the rename made no step (Undo reads \(undo.label))")
        design.shot("layers-renamed")

        // 2. An empty name is refused: the field closes, the row keeps Avatar, and nothing is
        // recorded, so one ⌘Z goes back past the Avatar step to A.
        a.staticTexts["Avatar"].firstMatch.doubleClick()
        XCTAssert(field.waitForExistence(timeout: 5), "double-clicking Avatar opened no rename field")
        design.press(character: "a", .command)
        design.press(.delete)
        design.press(.return)
        XCTAssert(field.waitForNonExistence(timeout: 5), "the empty rename left the field open")
        XCTAssert(a.staticTexts["Avatar"].exists, "the empty rename changed the row")
        expectOneStep(design, undone: { a.staticTexts["A"].exists }, redone: { a.staticTexts["Avatar"].exists },
                      "Rename Layer")

        // 3. Drag B onto C's top edge: B lists above C, one Move Layer step.
        XCTAssert(Self.isAbove(c, b), "two-pages doesn't list C above B")
        rowDrag(b, to: c.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.1)))
        XCTAssert(Self.waitUntil { Self.isAbove(b, c) }, "dragging B onto C's top edge didn't list B above C")
        XCTAssert(Self.waitUntil { undo.label == "Undo Move Layer" }, "the drag made no Move Layer step (Undo reads \(undo.label))")
        design.shot("layers-moved")
        expectOneStep(design, undone: { Self.isAbove(c, b) }, redone: { Self.isAbove(b, c) }, "Move Layer")

        // 4. Drag Title onto the middle of Pair's row: Title is nested at E1's depth, one Move Layer step.
        let title = design.element(Self.titleRow), pair = design.element(Self.pairRow)
        rowDrag(title, to: pair.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)))
        XCTAssert(Self.waitUntil { undo.label == "Undo Move Layer" && !Self.isDepth(title, of: a) },
                  "dragging Title onto Pair didn't move it out of Desktop's rows")
        design.expandDesignLayer(Self.pairRow)
        let e1 = design.element(Self.childRows[0])
        XCTAssert(e1.waitForExistence(timeout: 5), "opening Pair showed no E1 row")
        XCTAssert(Self.waitUntil { Self.isDepth(title, of: e1) }, "Title isn't nested under Pair beside E1")
        design.shot("layers-nested")
        expectOneStep(design, undone: { Self.isDepth(title, of: a) }, redone: { Self.isDepth(title, of: e1) }, "Move Layer")

        // 5. B selected, Object > Arrange > Send to Back: B is Desktop's last row, one Send to Back step.
        design.clickDesignLayer(Self.bRow)
        let object = design.app.menuBars.firstMatch.menuBarItems["Object"]
        object.click()
        design.app.menuItems["Arrange"].click()
        design.app.menuItems["Send to Back"].click()
        XCTAssert(Self.waitUntil { Self.isAbove(a, b) }, "Send to Back didn't list B under A, Desktop's last row")
        XCTAssert(Self.waitUntil { undo.label == "Undo Send to Back" }, "Send to Back made no step (Undo reads \(undo.label))")
        design.shot("layers-sent-back")
        expectOneStep(design, undone: { Self.isAbove(b, a) }, redone: { Self.isAbove(a, b) }, "Send to Back")

        // 6. Page > Rename Page… stays off until it has a name field (#3148, which adds the Mobile to
        // Phone screens step here).
        let page = design.app.menuBars.firstMatch.menuBarItems["Page"]
        page.click()
        let renamePage = design.app.menuItems["Rename Page…"]
        XCTAssert(renamePage.waitForExistence(timeout: 3), "the Page menu shows no Rename Page…")
        XCTAssertFalse(renamePage.isEnabled, "Page > Rename Page… is on with no name field to rename from")
        design.press(.escape)
    }

    /// Drags `row` from its middle to `target` the way a hand does with the mouse: a held click,
    /// a slow move, and a short hold before the release, so the system drag reports the pointer
    /// over the target row. On macOS the velocity form of `press` drives only the Touch Bar.
    @MainActor private func rowDrag(_ row: XCUIElement, to target: XCUICoordinate) {
        row.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .click(forDuration: 0.6, thenDragTo: target, withVelocity: 200, thenHoldForDuration: 0.5)
    }

    /// One ⌘Z makes `undone` true and ⇧⌘Z makes `redone` true again: the last step was one `step`.
    @MainActor private func expectOneStep(
        _ design: Journey, undone: () -> Bool, redone: () -> Bool, _ step: String
    ) {
        design.press(character: "z", .command)
        XCTAssert(Self.waitUntil(undone), "one ⌘Z didn't take the whole \(step) back")
        design.press(character: "z", [.command, .shift])
        XCTAssert(Self.waitUntil(redone), "⇧⌘Z didn't redo the \(step)")
    }

    /// Whether `upper` lists above `lower` in Layers.
    @MainActor private static func isAbove(_ upper: XCUIElement, _ lower: XCUIElement) -> Bool {
        upper.exists && lower.exists && upper.frame.midY < lower.frame.midY
    }

    /// Whether `row`'s name starts where `other`'s does: the two rows are at one depth.
    @MainActor private static func isDepth(_ row: XCUIElement, of other: XCUIElement) -> Bool {
        let (name, otherName) = (row.staticTexts.firstMatch, other.staticTexts.firstMatch)
        return name.exists && otherName.exists && abs(name.frame.minX - otherName.frame.minX) < 2
    }

    @MainActor private static func waitUntil(timeout: Double = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        } while Date() < deadline
        return condition()
    }

    /// L-6 (#2758, #589): an open group's row has an eye. A click hides the group as one
    /// "Hide Layer" step; its children read hidden by it and stay listed; ⌘Z shows it again.
    @MainActor func testGroupRowEyeHidesGroup() {
        let design = Journey("Design", self, arguments: ["-DesignFixture", "cards"])
        XCTAssert(design.element(Self.desktopRow).waitForExistence(timeout: 30), "cards showed no Desktop row")
        design.expandDesignLayer(Self.desktopRow)
        design.expandDesignLayer(Self.pairRow)
        for child in Self.childRows {
            XCTAssert(design.element(child).waitForExistence(timeout: 5), "opening Pair showed no \(child) row")
        }
        // Pair's row is one checkbox (#2410): its eye is at the x of E1's own eye, on Pair's row.
        let pair = design.element(Self.pairRow), e1 = design.element(Self.childRows[0])
        let childEye = design.designLayerToggle(e1, "Hide Layer")
        XCTAssert(childEye.waitForExistence(timeout: 5), "E1's row has no Hide Layer eye")
        design.shot("layers-group-open")
        let eyeOffset = CGVector(dx: childEye.frame.midX - pair.frame.minX, dy: pair.frame.height / 2)
        pair.coordinate(withNormalizedOffset: .zero).withOffset(eyeOffset).click()
        XCTAssert(design.app.buttons["Undo Hide Layer"].waitForExistence(timeout: 5), "Pair's eye made no undo step")
        for child in Self.childRows {
            let row = design.element(child)
            XCTAssert(row.exists, "hiding Pair collapsed it: no \(child) row")
            XCTAssert(design.designLayerToggle(row, "Hide Layer (its group is hidden)").waitForExistence(timeout: 5),
                      "\(child) doesn't show Pair's hidden state")
        }
        design.shot("layers-group-hidden")
        design.press(character: "z", .command)
        XCTAssert(e1.exists, "⌘Z collapsed Pair")
        XCTAssert(design.designLayerToggle(e1, "Hide Layer").waitForExistence(timeout: 5),
                  "⌘Z left Pair hidden: E1 still reads its group hidden")
        design.shot("layers-group-shown")
    }
}
