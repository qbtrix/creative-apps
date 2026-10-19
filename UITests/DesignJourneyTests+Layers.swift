// DesignJourneyTests+Layers.swift: the Layers steps Design's journeys share,
// and J12, the Layers panel's own journey (packet
// docs/blueprints/design/features/layers-panel.md, Journey steps, LP-a, L-5).
// A document opens with every layer row collapsed (DesignWorkspace.load clears
// the expanded rows), so on `cards` only Desktop's row shows until its
// disclosure opens; a journey that clicks A, Title or Hidden opens Desktop
// first (#2456, #2457). The disclosure is the triangle in the parent's
// outline row, found by the row's `design.layer.<id>`; clicking it changes
// no selection and records no step. A row is clicked in its blank space,
// between the name and the Hide toggle: a click on the name itself doesn't
// select the row (#2496).
// J12, on `two-pages` at 1024 × 768 (Layers lists Desktop front to back as
// Hidden, Locked, Pair, Title, C, B, A): A's name double-clicked, "Avatar"
// typed and Return is one "Rename Layer" step; an empty name is refused and
// records nothing; B's row dragged onto the top of C's is one "Move Layer"
// step (B above C); Title dragged onto the middle of Pair's row nests it as
// Pair's frontmost child (one "Move Layer"); B selected and Object > Arrange >
// Send to Back puts B last ("Send to Back"). Each step is checked as one step:
// the Edit menu's Undo names it, one ⌘Z restores the rows before it, and ⇧⌘Z
// redoes it. Pair, left open, is hidden from its own row's eye (one element,
// `suite.sidebar.node-6.hidden`): one "Hide Layer" step that hides its
// children while Pair stays open, since the expanded rows are the workspace's
// and no edit or undo closes them; ⌘Z shows it (L-6, #2758). One step is
// written and skipped by name: page "Mobile" renamed with Page > Rename
// Page…, which has no name field yet (#3148).
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
}

final class DesignLayersJourneyTests: XCTestCase {
    static let arguments = ["-DesignFixture", "two-pages", "-SuiteWindowSize", "1024x768"]
    /// Rows in Layers (DesignFixtures two-pages): Desktop holds A, B, C, Title, Pair (E1, E2), Locked, Hidden.
    static let desktop = "design.layer.node-1", a = "design.layer.node-2", b = "design.layer.node-3"
    static let c = "design.layer.node-4", title = "design.layer.node-5", pair = "design.layer.node-6"
    static let e1 = "design.layer.node-7", e2 = "design.layer.node-8", locked = "design.layer.node-9"
    static let hidden = "design.layer.node-10"

    /// J12: rename, the refused empty rename, reorder, nest and Send to Back, each one undo step.
    @MainActor func testLayersRenameReorderNest() throws {
        let design = Journey("Design", self, arguments: Self.arguments)
        XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(design.element("suite.canvas").waitForExistence(timeout: 10), "the fixture showed no page (suite.canvas)")
        design.expandDesignLayer(Self.desktop)
        var skips: [String] = []

        // 1. A's name double-clicked, "Avatar" typed, Return: the row reads Avatar, one Rename Layer step.
        rename(design, Self.a, from: "A", to: "Avatar")
        XCTAssert(Self.waitUntil { self.reads(design, Self.a, "Avatar") }, "the A row doesn't read Avatar after the rename")
        design.shot("layers-renamed")
        oneStep(design, "Undo Rename Layer") { self.reads(design, Self.a, "Avatar") } before: { self.reads(design, Self.a, "A") }

        // 2. An empty name: refused, the row keeps Avatar, nothing recorded (one ⌘Z still gives back A).
        rename(design, Self.a, from: "Avatar", to: "")
        XCTAssertFalse(Self.waitUntil(timeout: 2) { !self.reads(design, Self.a, "Avatar") }, "an empty rename changed the Avatar row")
        oneStep(design, "Undo Rename Layer") { self.reads(design, Self.a, "Avatar") } before: { self.reads(design, Self.a, "A") }

        // 3. B's row dragged onto the top of C's: B above C, one Move Layer step.
        let start = [Self.desktop, Self.hidden, Self.locked, Self.pair, Self.title, Self.c, Self.b, Self.a]
        let reordered = [Self.desktop, Self.hidden, Self.locked, Self.pair, Self.title, Self.b, Self.c, Self.a]
        XCTAssertEqual(order(design), start, "Layers doesn't list Desktop front to back")
        drag(design, Self.b, onto: Self.c, dy: 0.2)
        XCTAssert(Self.waitUntil { self.order(design) == reordered }, "dragging B onto C's top left \(order(design))")
        design.shot("layers-reordered")
        oneStep(design, "Undo Move Layer") { self.order(design) == reordered } before: { self.order(design) == start }

        // 4. Pair opened (no step), Title dragged onto the middle of Pair's row: Title is Pair's frontmost child.
        design.expandDesignLayer(Self.pair)
        let open = [Self.desktop, Self.hidden, Self.locked, Self.pair, Self.e2, Self.e1, Self.title, Self.b, Self.c, Self.a]
        let nested = [Self.desktop, Self.hidden, Self.locked, Self.pair, Self.title, Self.e2, Self.e1, Self.b, Self.c, Self.a]
        XCTAssert(Self.waitUntil { self.order(design) == open }, "opening Pair left \(order(design))")
        XCTAssertEqual(editMenuUndo(design), "Undo Move Layer", "opening Pair recorded a step")
        drag(design, Self.title, onto: Self.pair, dy: 0.5)
        XCTAssert(Self.waitUntil { self.order(design) == nested }, "dragging Title into Pair left \(order(design))")
        XCTAssertGreaterThan(indent(design, Self.title), indent(design, Self.b), "Title's row isn't indented under Pair")
        design.shot("layers-nested")
        oneStep(design, "Undo Move Layer") { self.order(design) == nested } before: { self.order(design) == open }

        // 5. B selected, Object > Arrange > Send to Back: B is Desktop's last row, one Send to Back step.
        let back = [Self.desktop, Self.hidden, Self.locked, Self.pair, Self.title, Self.e2, Self.e1, Self.c, Self.a, Self.b]
        design.clickDesignLayer(Self.b)
        design.app.menuBars.firstMatch.menuBarItems["Object"].click()
        design.app.menuItems["Arrange"].click()
        design.app.menuItems["Send to Back"].click()
        XCTAssert(Self.waitUntil { self.order(design) == back }, "Send to Back left \(order(design))")
        design.shot("layers-sent-to-back")
        oneStep(design, "Undo Send to Back") { self.order(design) == back } before: { self.order(design) == nested }

        // 6. Pair open, its own row's eye hides it and its children without closing it; ⌘Z shows it.
        hidePairFromItsRow(design, rows: back)
        // 7. Page "Mobile" renamed with Page > Rename Page…: written, skipped until the menu has a name field.
        skips.append("rename a page with Page > Rename Page… waits on #3148: the menu item has no name field")
        if !skips.isEmpty { throw XCTSkip(skips.joined(separator: "; ")) }
        renameMobilePage(design)
    }

    /// Opens Pair, clicks its own eye (one element, `suite.sidebar.node-6.hidden`): one "Hide Layer"
    /// step that hides Pair's children too (their eyes say the group is hidden, the rule the canvas
    /// draws by) while Pair stays open (`rows` still show); ⌘Z shows Pair and its children again.
    @MainActor private func hidePairFromItsRow(_ design: Journey, rows: [String]) {
        design.expandDesignLayer(Self.pair)
        let id = "suite.sidebar.node-6.hidden"
        let count = design.app.descendants(matching: .any).matching(identifier: id).count
        XCTAssertEqual(count, 1, "Pair's eye is \(count) elements, not its own one")
        let eye = design.element(id)
        XCTAssert(eye.waitForExistence(timeout: 5), "Pair's row has no Hide toggle")
        // Pair holds Title (nested in step 4), E2 and E1.
        let children = ["node-5", "node-8", "node-7"].map { design.element("suite.sidebar.\($0).hidden") }
        eye.click()
        XCTAssert(Self.waitUntil { eye.label == "Show Layer" }, "Pair's eye reads \(eye.label) after a click, not Show Layer")
        XCTAssertEqual(editMenuUndo(design), "Undo Hide Layer", "hiding Pair isn't one Hide Layer step")
        for child in children {
            let hidden = "Hide Layer (its group is hidden)"
            XCTAssert(Self.waitUntil { child.label == hidden }, "\(child.identifier) reads \(child.label) with Pair hidden")
        }
        XCTAssertEqual(order(design), rows, "hiding Pair closed it or moved a row")
        design.shot("layers-group-hidden")
        design.press(character: "z", .command)
        XCTAssert(Self.waitUntil { eye.label == "Hide Layer" }, "⌘Z left Pair's eye reading \(eye.label)")
        XCTAssert(Self.waitUntil { children.allSatisfy { $0.label == "Hide Layer" } }, "⌘Z left a child of Pair hidden")
        XCTAssertEqual(order(design), rows, "⌘Z on Hide Layer closed Pair or moved a row")
    }

    // MARK: Skipped steps

    /// Mobile chosen, Page > Rename Page…, "Phone screens", Return: one Rename Page step.
    @MainActor private func renameMobilePage(_ design: Journey) {
        let page = design.element("design.page.row.page-2")
        XCTAssert(page.waitForExistence(timeout: 5), "no Mobile page row")
        page.click()
        design.app.menuBars.firstMatch.menuBarItems["Page"].click()
        design.app.menuItems["Rename Page…"].click()
        let field = design.element("suite.sidebar").textFields.firstMatch
        XCTAssert(field.waitForExistence(timeout: 5), "Rename Page… opened no name field")
        design.press(character: "a", .command)
        field.typeText("Phone screens")
        design.press(.return)
        XCTAssert(Self.waitUntil { Self.text(page).contains("Phone screens") }, "the page row reads \(Self.text(page))")
        XCTAssertEqual(editMenuUndo(design), "Undo Rename Page", "renaming the page isn't one Rename Page step")
        design.shot("layers-page-renamed")
    }

    // MARK: Helpers

    /// Checks the last edit was one step named `undo`: the Edit menu says so, one ⌘Z gives back
    /// `before`, and ⇧⌘Z gives back `after`.
    @MainActor private func oneStep(
        _ design: Journey, _ undo: String, after: () -> Bool, before: () -> Bool, line: UInt = #line
    ) {
        XCTAssert(Self.waitUntil(after), "the edit didn't show before its undo check", line: line)
        XCTAssertEqual(editMenuUndo(design), undo, "the Edit menu's Undo doesn't name the edit", line: line)
        design.press(character: "z", .command)
        XCTAssert(Self.waitUntil(before), "one ⌘Z didn't undo \(undo): the edit was more or less than one step", line: line)
        design.press(character: "z", [.command, .shift])
        XCTAssert(Self.waitUntil(after), "⇧⌘Z didn't redo \(undo)", line: line)
    }

    /// Opens `identifier`'s name field with a double-click on its name `from`, types `to` over it, presses Return.
    @MainActor private func rename(_ design: Journey, _ identifier: String, from: String, to: String) {
        let name = layer(design, identifier).staticTexts[from].firstMatch
        XCTAssert(name.waitForExistence(timeout: 5), "the \(identifier) row shows no \(from)")
        name.doubleClick()
        let id = identifier.replacingOccurrences(of: "design.layer.", with: "")
        let field = design.element("suite.sidebar.\(id).rename")
        XCTAssert(field.waitForExistence(timeout: 5), "a double-click on \(from) opened no name field")
        design.press(character: "a", .command)
        if to.isEmpty { design.press(.delete) } else { field.typeText(to) }
        design.press(.return)
    }

    /// Drags the row `identifier` from its blank space onto the row `target` at `dy` of its height.
    @MainActor private func drag(_ design: Journey, _ identifier: String, onto target: String, dy: Double) {
        let from = layer(design, identifier).coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5))
        let to = layer(design, target).coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: dy))
        from.press(forDuration: 0.3, thenDragTo: to)
    }

    /// The Layers row `identifier`.
    @MainActor private func layer(_ design: Journey, _ identifier: String) -> XCUIElement {
        let row = design.element("suite.sidebar").descendants(matching: .any)[identifier].firstMatch
        XCTAssert(row.waitForExistence(timeout: 5), "no \(identifier) row in Layers")
        return row
    }

    /// Whether the row `identifier` reads `name`.
    @MainActor private func reads(_ design: Journey, _ identifier: String, _ name: String) -> Bool {
        let row = design.element("suite.sidebar").descendants(matching: .any)[identifier].firstMatch
        return row.exists && (row.label == name || row.label.hasPrefix(name + ",") || row.staticTexts[name].exists)
    }

    /// The Layers rows showing now, top to bottom, by identifier.
    @MainActor private func order(_ design: Journey) -> [String] {
        let rows = design.element("suite.sidebar").descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH 'design.layer.'")).allElementsBoundByIndex
        var seen = Set<String>()
        return rows.map { ($0.identifier, $0.frame.minY) }.sorted { $0.1 < $1.1 }
            .map(\.0).filter { seen.insert($0).inserted }
    }

    /// Where the row `identifier`'s name starts, left to right.
    @MainActor private func indent(_ design: Journey, _ identifier: String) -> CGFloat {
        layer(design, identifier).staticTexts.firstMatch.frame.minX
    }

    /// The title of Edit's Undo item now, read from the open menu.
    @MainActor private func editMenuUndo(_ design: Journey) -> String {
        let edit = design.app.menuBars.firstMatch.menuBarItems["Edit"]
        edit.click()
        let item = edit.menuItems.matching(NSPredicate(format: "title BEGINSWITH %@", "Undo")).firstMatch
        let title = item.waitForExistence(timeout: 3) ? item.title : ""
        design.press(.escape)
        return title
    }

    /// What an element reads: its value where macOS puts a text's string, else its label.
    @MainActor private static func text(_ element: XCUIElement) -> String {
        let value = element.value as? String ?? ""
        return value.isEmpty ? element.label : value
    }

    /// Whether `condition` holds within `timeout` seconds.
    @MainActor private static func waitUntil(timeout: Double = 5, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        } while Date() < deadline
        return condition()
    }
}
