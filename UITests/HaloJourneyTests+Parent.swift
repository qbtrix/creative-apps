// HaloJourneyTests+Parent.swift: H-J23, parent a layer and set its blend
// from the LAYER group (layer-keys LK-14, #1036;
// docs/blueprints/halo/features/layer-keys.md, Journey steps 3). On
// `-HaloFixture parented` at frame 0 (Bounce: Rig, a null keyed on x at 960
// and 1160, over Ball at x 160 and Floor) it selects Ball, whose Parent menu
// lists None, Floor and Rig but not Ball, parents it to Rig (Position X stays
// 160.0 px: Rig's world matrix is the identity at 0), finds no Ball in Rig's
// Parent menu, types 1060 into Rig's Position X (Ball still reads 160.0 px,
// its local value), sets Ball's Blend to Multiply, then unparents it: Ball
// keeps its place on screen, so Position X reads 260.0 px, and Edit holds
// "Undo Set Parent". The Parent and Blend pickers are InspectorPickerRows: a
// Menu (a menu button labelled "Parent" or "Blend" under `suite.inspector`)
// whose row carries `halo.inspector.parent` / `.blend` and the current title
// as its value. Positions come from the TRANSFORM rows
// (`halo.inspector.row.x`, value "160.0 px"). A row's bar opens its typing
// field on a click, as H-J6 types into Rotation. Undo stays history-files':
// the Edit item is only looked up, ⌘Z is never pressed. Shots:
// `halo-parent-*`, a menu's on the whole screen. The name sorts before
// testScrubTheTimeline, so H-J3 still runs last.
import XCTest

extension HaloJourneyTests {
    /// H-J23: parent Ball to Rig and back, keeping it on screen, and blend it.
    @MainActor func testParentAndBlend() {
        let halo = Journey("Halo", self, arguments: ["-HaloFixture", "parented", "-HaloWindowSize", "1000x640"])
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")

        // 1. Select Ball: its Parent menu lists None, Floor and Rig, not Ball.
        parentSelect("comp-1-layer-2", named: "Ball", halo)
        parentExpectX("160.0 px", halo)
        let ballChoices = parentOpenPicker("halo.inspector.parent", label: "Parent", halo)
        for name in ["None", "Floor", "Rig"] {
            XCTAssert(ballChoices.contains(name), "Ball's Parent menu lists \(ballChoices), no \(name)")
        }
        XCTAssertFalse(ballChoices.contains("Ball"), "Ball's Parent menu lists Ball itself: \(ballChoices)")
        halo.shot("parent-menu-ball", screen: true)

        // 2. Choose Rig: Ball's Position X still reads 160.0 px.
        parentChooseItem("Rig", halo)
        parentExpectValue("Rig", of: "halo.inspector.parent", label: "Parent", halo)
        parentExpectX("160.0 px", halo)
        halo.shot("parent-ball-rig")

        // 3. Select Rig: its Parent menu has no Ball (Ball follows Rig).
        parentSelect("comp-1-layer-3", named: "Rig", halo)
        let rigChoices = parentOpenPicker("halo.inspector.parent", label: "Parent", halo)
        XCTAssert(rigChoices.contains("None"), "Rig's Parent menu lists \(rigChoices), no None")
        XCTAssertFalse(rigChoices.contains("Ball"), "Rig's Parent menu lists Ball, its child: \(rigChoices)")
        halo.shot("parent-rig-menu", screen: true)
        halo.press(.escape)
        _ = halo.app.menus.firstMatch.waitForNonExistence(timeout: 2)

        // 4. Type 1060 into Rig's Position X.
        parentExpectX("960.0 px", halo)
        parentType("1060", into: "halo.inspector.row.x", halo)
        parentExpectX("1060.0 px", halo)
        halo.shot("parent-rig-x-1060")

        // 5. Select Ball: still 160.0 px. Blend → Multiply: the row reads Multiply.
        parentSelect("comp-1-layer-2", named: "Ball", halo)
        parentExpectX("160.0 px", halo)
        let blends = parentOpenPicker("halo.inspector.blend", label: "Blend", halo)
        XCTAssert(blends.contains("Multiply"), "the Blend menu lists \(blends), no Multiply")
        parentChooseItem("Multiply", halo)
        parentExpectValue("Multiply", of: "halo.inspector.blend", label: "Blend", halo)
        halo.shot("parent-blend-multiply")

        // 6. Parent → None: Ball stays on screen at 260.0 px; Edit holds Undo Set Parent.
        _ = parentOpenPicker("halo.inspector.parent", label: "Parent", halo)
        parentChooseItem("None", halo)
        parentExpectValue("None", of: "halo.inspector.parent", label: "Parent", halo)
        parentExpectX("260.0 px", halo)
        parentExpectEditItem("Undo Set Parent", halo)
        halo.shot("parent-none-kept")
    }

    // MARK: - Parent helpers

    /// Clicks layer `id`'s row in the layer list; the header names `name`.
    @MainActor private func parentSelect(_ id: String, named name: String, _ halo: Journey) {
        let row = halo.element("halo.layer.row.\(id)")
        XCTAssert(row.waitForExistence(timeout: 10), "no \(name) row (halo.layer.row.\(id))")
        row.click()
        XCTAssert(
            parentInspectorHeader(name, halo).waitForExistence(timeout: 5),
            "clicking the \(name) row didn't select it: the header reads \(halo.element("halo.inspector.header").label)")
    }

    /// The inspector header whose label contains `text`.
    @MainActor private func parentInspectorHeader(_ text: String, _ halo: Journey) -> XCUIElement {
        halo.app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == 'halo.inspector.header' AND label CONTAINS %@", text)).firstMatch
    }

    /// The picker's menu button: under the inspector, a menu, pop-up or
    /// plain button with the row's identifier or the picker's label.
    @MainActor private func parentPicker(_ id: String, label: String, _ halo: Journey) -> XCUIElement {
        let types = [XCUIElement.ElementType.menuButton, .popUpButton, .button].map { NSNumber(value: $0.rawValue) }
        return halo.element("suite.inspector").descendants(matching: .any).matching(
            NSPredicate(format: "elementType IN %@ AND (identifier == %@ OR label == %@)", types, id, label)
        ).firstMatch
    }

    /// Clicks the picker open and returns its menu's item titles.
    @MainActor private func parentOpenPicker(_ id: String, label: String, _ halo: Journey) -> [String] {
        let picker = parentPicker(id, label: label, halo)
        XCTAssert(picker.waitForExistence(timeout: 5), "no \(label) menu (\(id))")
        XCTAssert(picker.isEnabled, "the \(label) menu is disabled")
        picker.click()
        let menu = halo.app.menus.firstMatch
        XCTAssert(menu.waitForExistence(timeout: 3), "clicking \(label) opened no menu")
        let items = menu.descendants(matching: .menuItem)
        XCTAssert(items.firstMatch.waitForExistence(timeout: 3), "the \(label) menu shows no items")
        return items.allElementsBoundByIndex.map { $0.title }
    }

    /// Clicks the open menu's item `title`; the menu closes.
    @MainActor private func parentChooseItem(_ title: String, _ halo: Journey) {
        let item = halo.app.menus.firstMatch.descendants(matching: .menuItem)
            .matching(NSPredicate(format: "title == %@", title)).firstMatch
        XCTAssert(item.waitForExistence(timeout: 3), "the open menu has no \(title)")
        item.click()
        _ = halo.app.menus.firstMatch.waitForNonExistence(timeout: 2)
    }

    /// The picker `id` (or its menu button) reads `value` within three seconds.
    @MainActor private func parentExpectValue(_ value: String, of id: String, label: String, _ halo: Journey) {
        let reading = halo.element("suite.inspector").descendants(matching: .any).matching(
            NSPredicate(format: "(identifier == %@ OR label == %@) AND value == %@", id, label, value)).firstMatch
        XCTAssert(
            reading.waitForExistence(timeout: 3),
            "\(label) reads \(String(describing: halo.element(id).value)), not \(value)")
    }

    /// The Position X row reads `text` ("160.0 px") within three seconds.
    @MainActor private func parentExpectX(_ text: String, _ halo: Journey) {
        let row = halo.element("halo.inspector.row.x")
        XCTAssert(row.waitForExistence(timeout: 5), "no Position X row (halo.inspector.row.x)")
        XCTAssert(
            parentWaitUntil { (row.value as? String) == text },
            "Position X reads \(String(describing: row.value)), not \(text)")
    }

    /// Clicks the bar `id` open, selects its text, types `text` and presses Return.
    @MainActor private func parentType(_ text: String, into id: String, _ halo: Journey) {
        let bar = halo.element(id)
        XCTAssert(bar.waitForExistence(timeout: 5), "no \(id)")
        bar.click()
        let field = halo.element("suite.inspector").textFields.firstMatch
        XCTAssert(field.waitForExistence(timeout: 5), "clicking \(id) opened no field")
        halo.press(character: "a", .command)
        field.typeText(text)
        halo.press(.return)
        XCTAssert(parentWaitUntil { !field.exists }, "Return didn't close \(id)'s field")
    }

    /// The Edit menu holds an item titled `title`; the menu is closed again. Never presses it.
    @MainActor private func parentExpectEditItem(_ title: String, _ halo: Journey) {
        let edit = halo.app.menuBars.firstMatch.menuBarItems["Edit"]
        XCTAssert(edit.waitForExistence(timeout: 5), "no Edit menu")
        edit.click()
        let item = edit.menus.firstMatch.menuItems.matching(NSPredicate(format: "title == %@", title)).firstMatch
        XCTAssert(item.waitForExistence(timeout: 3), "the Edit menu has no \(title)")
        halo.press(.escape)
        _ = halo.app.menus.firstMatch.waitForNonExistence(timeout: 2)
    }

    /// Whether `condition` holds within three seconds.
    @MainActor private func parentWaitUntil(_ condition: () -> Bool) -> Bool {
        for _ in 0..<15 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }
}
