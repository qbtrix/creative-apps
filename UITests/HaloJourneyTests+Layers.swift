// HaloJourneyTests+Layers.swift: H-J9, layer housekeeping (layer-panel,
// #770; docs/blueprints/halo/features/layer-panel.md, Journey steps). On the
// `three-layers` fixture (Intro; Title, Badge, Background, Rig, top first) it
// selects, duplicates, renames on the row, refuses a blank rename from
// Layer > Rename…, drags a row to the bottom, brings it forward, deletes it,
// then deletes every layer with ⌫ from the timeline. Rows are found by their
// `halo.layer.row.<layer id>` identifiers (the fixture's ids; the copy takes
// the next unused number, 5), the artboard by its `halo.viewer` value (the
// Model's viewerSummary). Undo stays disabled until history-files lands, so
// each step reads the Edit menu's first item title and never presses ⌘Z.
// A disabled menu item's reason is its help tag, read by hovering it. One
// shot per step, `halo-layers-<step>`, plus the rename prompt
// (`halo-layers-4-prompt`), each taken once every menu it opened has gone.
import XCTest

final class HaloLayersJourneyTests: XCTestCase {
    /// The fixture's layer ids, and the duplicate's.
    private static let rig = "comp-1-layer-1", background = "comp-1-layer-2", badge = "comp-1-layer-3"
    private static let titleLayer = "comp-1-layer-4", badgeCopy = "comp-1-layer-5"

    /// H-J9: every layer edit from the list, the Layer menu and the timeline.
    @MainActor func testLayerHousekeeping() {
        let halo = Journey("Halo", self, arguments: ["-HaloFixture", "three-layers", "-HaloWindowSize", "1000x640"])
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(halo.element("halo.layer.list").waitForExistence(timeout: 10), "no layer list (halo.layer.list)")

        // 1. Select Badge in the list.
        row(Self.badge, in: halo).click()
        XCTAssert(waitFor { self.row(Self.badge, in: halo).isSelected }, "clicking Badge didn't select it")
        halo.shot("layers-1")

        // 2. Layer > Duplicate: "Badge copy" above Badge, selected.
        choose("Duplicate", in: "Layer", halo)
        expectRows([Self.titleLayer, Self.badgeCopy, Self.badge, Self.background, Self.rig], in: halo)
        XCTAssert(row(Self.badgeCopy, in: halo).label.contains("Badge copy"), "the copy isn't named Badge copy")
        XCTAssert(waitFor { self.row(Self.badgeCopy, in: halo).isSelected }, "the copy isn't selected")
        expectUndo("Undo Duplicate Layer", halo)
        halo.shot("layers-2")

        // 3. Double-click the copy's name, type Badge 2, Return.
        let copyRow = row(Self.badgeCopy, in: halo)
        let name = copyRow.staticTexts.firstMatch
        if name.exists {
            name.doubleClick()
        } else {
            // The name starts after the row's padding and icon; aim inside it.
            copyRow.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: 48, dy: copyRow.frame.height / 2)).doubleClick()
        }
        let field = halo.element("halo.layer.list").textFields.firstMatch
        XCTAssert(field.waitForExistence(timeout: 5), "double-clicking the name opened no rename field")
        halo.press(character: "a", .command)
        field.typeText("Badge 2")
        halo.press(.return)
        XCTAssert(waitFor { self.row(Self.badgeCopy, in: halo).label.contains("Badge 2") }, "the row doesn't read Badge 2")
        expectUndo("Undo Rename Layer", halo)
        halo.shot("layers-3")

        // 4. Layer > Rename…, clear the field, Rename: refused under the row.
        choose("Rename…", in: "Layer", halo)
        let prompt = renamePrompt(halo)
        let promptField = prompt.textFields.firstMatch
        XCTAssert(promptField.waitForExistence(timeout: 5), "the Rename Layer prompt has no field")
        promptField.click()
        halo.press(character: "a", .command)
        halo.press(.delete)
        halo.shot("layers-4-prompt", screen: true)
        prompt.buttons["Rename"].click()
        let refusal = halo.element("halo.layer.refusal")
        XCTAssert(refusal.waitForExistence(timeout: 5), "a blank rename shows no refusal (halo.layer.refusal)")
        XCTAssert(reads("Enter a name.", refusal), "the refusal doesn't read Enter a name.: \(refusal.label)")
        XCTAssert(row(Self.badgeCopy, in: halo).label.contains("Badge 2"), "a refused rename changed the row")
        expectUndo("Undo Rename Layer", halo)
        halo.shot("layers-4")

        // 5. Drag Badge 2 below Rig.
        let rigRow = row(Self.rig, in: halo)
        row(Self.badgeCopy, in: halo).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.6, thenDragTo: rigRow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)))
        expectRows([Self.titleLayer, Self.badge, Self.background, Self.rig, Self.badgeCopy], in: halo)
        XCTAssert(waitFor { !halo.element("halo.layer.refusal").exists }, "the refusal caption outlived a move")
        expectArtboard("Frame 0: Badge 2, Background, Badge", halo)
        expectUndo("Undo Move Layer", halo)
        halo.shot("layers-5")

        // 6. Send Backward is off at the bottom; Bring Forward.
        expectDisabled("Send Backward", in: "Layer", help: "This layer is already at the bottom.", halo)
        choose("Bring Forward", in: "Layer", halo)
        expectRows([Self.titleLayer, Self.badge, Self.background, Self.badgeCopy, Self.rig], in: halo)
        expectUndo("Undo Move Layer", halo)
        halo.shot("layers-6")

        // 7. Layer > Delete: Rig takes Badge 2's place and is selected.
        choose("Delete", in: "Layer", halo)
        expectRows([Self.titleLayer, Self.badge, Self.background, Self.rig], in: halo)
        XCTAssert(waitFor { self.row(Self.rig, in: halo).isSelected }, "Rig isn't selected after the delete")
        expectArtboard("Frame 0: Background, Badge", halo)
        expectUndo("Undo Delete Layer", halo)
        halo.shot("layers-7")

        // 8. Click Rig's lane (selects Rig, focuses the timeline), ⌫ four times.
        let lane = halo.app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == 'halo.timeline.track' AND label == 'Rig'")).firstMatch
        XCTAssert(lane.waitForExistence(timeout: 5), "no Rig lane in the timeline")
        lane.click()
        let remaining = [[Self.titleLayer, Self.badge, Self.background], [Self.titleLayer, Self.badge], [Self.titleLayer], []]
        for rows in remaining {
            halo.press(.delete)
            expectRows(rows, in: halo)
        }
        let empty = halo.element("halo.layer.empty")
        XCTAssert(empty.waitForExistence(timeout: 5), "no empty-list text (halo.layer.empty)")
        XCTAssert(reads("No layers yet. Add one from Layer > New.", empty), "the empty list reads \(empty.label)")
        expectArtboard("Frame 0: no layers", halo)
        expectDisabled("Delete", in: "Layer", help: "Select a layer first.", halo)
        halo.shot("layers-8")
    }

    // MARK: - Helpers

    /// Layer `id`'s row in the list.
    @MainActor private func row(_ id: String, in halo: Journey) -> XCUIElement {
        halo.element("halo.layer.row.\(id)")
    }

    /// The layer ids of the list's rows, top first.
    @MainActor private func rowIDs(_ halo: Journey) -> [String] {
        let prefix = "halo.layer.row."
        let rows = halo.app.descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).allElementsBoundByIndex
            .map { ($0.identifier, $0.frame.minY) }.sorted { $0.1 < $1.1 }
        var seen = Set<String>()
        return rows.map { String($0.0.dropFirst(prefix.count)) }.filter { seen.insert($0).inserted }
    }

    /// The list shows exactly `ids`, top first, within three seconds.
    @MainActor private func expectRows(_ ids: [String], in halo: Journey) {
        XCTAssert(waitFor { self.rowIDs(halo) == ids }, "the rows are \(rowIDs(halo)), not \(ids)")
    }

    /// The artboard (`halo.viewer`) reads `summary`.
    @MainActor private func expectArtboard(_ summary: String, _ halo: Journey) {
        let artboard = halo.element("halo.viewer")
        XCTAssert(
            waitFor { (artboard.value as? String) == summary },
            "the artboard reads \(String(describing: artboard.value)), not \(summary)")
    }

    /// Opens `menu` and clicks its enabled item `item`.
    @MainActor private func choose(_ item: String, in menu: String, _ halo: Journey) {
        let entry = openMenu(menu, halo).menuItems[item]
        XCTAssert(entry.waitForExistence(timeout: 3), "the \(menu) menu has no \(item)")
        XCTAssert(entry.isEnabled, "\(menu) > \(item) is disabled")
        entry.click()
        expectClosed(menu, halo)
    }

    /// `menu`'s item `item` is disabled and its help tag reads `help`.
    @MainActor private func expectDisabled(_ item: String, in menu: String, help: String, _ halo: Journey) {
        let entry = openMenu(menu, halo).menuItems[item]
        XCTAssert(entry.waitForExistence(timeout: 3), "the \(menu) menu has no \(item)")
        XCTAssertFalse(entry.isEnabled, "\(menu) > \(item) is enabled")
        entry.hover()
        let tag = halo.app.helpTags.matching(
            NSPredicate(format: "label CONTAINS %@ OR title CONTAINS %@ OR value CONTAINS %@", help, help, help))
        XCTAssert(tag.firstMatch.waitForExistence(timeout: 5), "\(menu) > \(item) doesn't say \(help)")
        halo.press(.escape)
        expectClosed(menu, halo)
    }

    /// The Edit menu's first item reads `title`; the menu is closed again.
    @MainActor private func expectUndo(_ title: String, _ halo: Journey) {
        let first = openMenu("Edit", halo).menus.firstMatch.children(matching: .menuItem).firstMatch
        XCTAssert(first.waitForExistence(timeout: 3), "the Edit menu shows no items")
        XCTAssertEqual(first.title, title, "the Edit menu's first item")
        halo.press(.escape)
        expectClosed("Edit", halo)
    }

    /// The open menu has faded out, so the next shot shows the window alone.
    @MainActor private func expectClosed(_ menu: String, _ halo: Journey) {
        XCTAssert(halo.app.menus.firstMatch.waitForNonExistence(timeout: 2), "the \(menu) menu stayed open")
    }

    /// Clicks the menu bar's `menu` open and returns it.
    @MainActor private func openMenu(_ menu: String, _ halo: Journey) -> XCUIElement {
        let bar = halo.app.menuBars.firstMatch.menuBarItems[menu]
        XCTAssert(bar.waitForExistence(timeout: 5), "no \(menu) menu")
        bar.click()
        return bar
    }

    /// The Rename Layer prompt: a SwiftUI alert, shown as the window's sheet
    /// (or as a dialog).
    @MainActor private func renamePrompt(_ halo: Journey) -> XCUIElement {
        let sheet = halo.app.sheets.firstMatch
        return sheet.waitForExistence(timeout: 5) ? sheet : halo.app.dialogs.firstMatch
    }

    /// `element`'s label, or its value for a plain text, contains `text`.
    @MainActor private func reads(_ text: String, _ element: XCUIElement) -> Bool {
        element.label.contains(text) || ((element.value as? String)?.contains(text) ?? false)
            || element.staticTexts.matching(NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", text, text))
                .firstMatch.exists
    }

    /// Whether `condition` holds within three seconds.
    @MainActor private func waitFor(_ condition: () -> Bool) -> Bool {
        for _ in 0..<15 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }
}
