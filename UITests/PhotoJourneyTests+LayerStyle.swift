// PhotoJourneyTests+LayerStyle.swift: PJ-Y1, a drop shadow and a stroke on a layer, copied to another, refused on an
// adjustment layer, and kept through a save (layer-styles PY-4 written, turned on in PY-8;
// docs/blueprints/photo/features/layer-styles.md, Journey steps 1-6). On `-PhotoFixture layered` (Paint, Curves 1,
// Background, top first; Paint selected) Layer > Layer Style… opens the panel (`suite.style.panel`) on Drop Shadow,
// off; its switch on and Distance dragged to 20 make one step that Undo (Command-Z) takes back; Stroke on at Outside,
// 4 px, Done (`photo.style.done`); Copy Layer Style, Select Layer Below twice to Background, Paste Layer Style, and
// Background's panel shows both switches on; Curves 1 selected, Layer Style… is disabled with "Layer styles go on
// pixel and text layers."; Command-S writes the fixture as .ora into `-PhotoSaveTo`, Command-Q, and the reopened file
// still shows Paint's switches on and editable. Switches are `suite.style.toggle.<kind>`; the row's controls are
// found by their labels ("Distance", "Position", "Size"), which LS-3 settles. Undo steps are read from the window
// toolbar's Undo button, as PhotoMultiLayerJourneyTests does. Skipped until PY-8: the style commands throw until
// LS-6 and PY-5. Shots: `layerstyle-*`.
import XCTest

final class PhotoLayerStyleJourneyTests: XCTestCase {
    /// PJ-Y1: style Paint with a drop shadow and a stroke, paste it on Background, refuse Curves 1, save and reopen.
    @MainActor func testDropShadowAndStroke() throws {
        throw XCTSkip("waits on PY-8")
        let folder = FileManager.default.temporaryDirectory.appending(path: "photo-layer-style-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        var photo = Journey("Photo", self, arguments: photoArguments(saveTo: folder, fixture: "layered"))
        XCTAssert(photo.element("photo.status.preview").waitForExistence(timeout: 30), "-PhotoFixture layered shows no Preview data pill")
        photo.shot("layerstyle-opened")

        // 1. Layer > Layer Style…: the panel opens on Drop Shadow, off.
        choose("Layer Style…", in: "Layer", photo)
        let panel = photo.element("suite.style.panel")
        XCTAssert(panel.waitForExistence(timeout: 5), "Layer Style… opened no panel (suite.style.panel)")
        let shadow = toggle("dropShadow", photo)
        XCTAssertFalse(isOn(shadow), "Drop Shadow starts on")
        photo.shot("layerstyle-1-panel")

        // 2. Drop Shadow on, Distance dragged to 20: the canvas follows; Edit > Undo takes the drag back.
        shadow.click()
        XCTAssert(waitUntil { self.isOn(shadow) }, "Drop Shadow didn't turn on")
        let canvas = photo.element("suite.canvas")
        XCTAssert(canvas.waitForExistence(timeout: 5), "no canvas (suite.canvas)")
        let unshifted = canvas.screenshot().pngRepresentation
        let distance = control(.slider, "Distance", in: panel)
        XCTAssert(distance.waitForExistence(timeout: 5), "the Drop Shadow row has no Distance slider")
        distance.adjust(toNormalizedSliderPosition: 0.2)
        expect("Undo Change Layer Style", photo, "the Distance drag made no Change Layer Style step")
        XCTAssert(waitUntil { canvas.screenshot().pngRepresentation != unshifted }, "the shadow didn't move on the canvas")
        photo.shot("layerstyle-2-shadow")
        let shifted = canvas.screenshot().pngRepresentation
        photo.press(character: "z", .command)
        XCTAssert(waitUntil { canvas.screenshot().pngRepresentation != shifted }, "Undo left the dragged shadow")
        expect("Redo Change Layer Style", photo, "Edit > Undo left nothing to redo")

        // 3. Stroke on, Outside, 4 px; Done.
        let stroke = toggle("stroke", photo)
        stroke.click()
        XCTAssert(waitUntil { self.isOn(stroke) }, "Stroke didn't turn on")
        let position = control(.popUpButton, "Position", in: panel)
        XCTAssert(position.waitForExistence(timeout: 5), "the Stroke row has no Position menu")
        position.click()
        photo.app.menuItems["Outside"].click()
        let size = control(.textField, "Size", in: panel)
        XCTAssert(size.waitForExistence(timeout: 5), "the Stroke row has no Size field")
        size.doubleClick()
        size.typeText("4\r")
        photo.shot("layerstyle-3-stroke")
        photo.element("photo.style.done").click()
        XCTAssert(panel.waitForNonExistence(timeout: 5), "Done didn't close the panel")

        // 4. Copy Layer Style, select Background, Paste Layer Style: Background's panel shows both on.
        choose("Copy Layer Style", in: "Layer", photo)
        choose("Select Layer Below", in: "Layer", photo)
        choose("Select Layer Below", in: "Layer", photo)
        choose("Paste Layer Style", in: "Layer", photo)
        expect("Undo Paste Layer Style", photo, "Paste Layer Style made no step")
        expectStyled(photo, "Background's pasted style")
        photo.shot("layerstyle-4-pasted")
        photo.element("photo.style.done").click()

        // 5. Curves 1, an adjustment layer: Layer Style… is disabled and says why.
        choose("Select Layer Above", in: "Layer", photo)
        expectDisabled("Layer Style…", in: "Layer", help: "Layer styles go on pixel and text layers.", photo)
        photo.shot("layerstyle-5-disabled")

        // 6. Save, quit, reopen: Paint's style is there and its switches still work.
        photo.press(character: "s", .command)
        let saved = try XCTUnwrap(waitForFile(in: folder), "Command-S wrote no .ora into -PhotoSaveTo")
        photo.press(character: "q", .command)
        if !photo.app.wait(for: .notRunning, timeout: 15) { photo.app.terminate() }
        photo = Journey("Photo", self, arguments: photoArguments(open: saved))
        XCTAssert(photo.window(named: saved.lastPathComponent).waitForExistence(timeout: 30), "\(saved.lastPathComponent) didn't reopen")
        choose("Layer Style…", in: "Layer", photo)
        expectStyled(photo, "Paint's reopened style")
        let reopened = toggle("stroke", photo)
        reopened.click()
        XCTAssert(waitUntil { !self.isOn(reopened) }, "the reopened Stroke switch doesn't turn off")
        photo.shot("layerstyle-6-reopened")
    }

    // MARK: - Steps

    /// Clicks `menu` in the menu bar, then its `item`.
    @MainActor private func choose(_ item: String, in menu: String, _ photo: Journey) {
        let bar = photo.app.menuBars.firstMatch.menuBarItems[menu]
        XCTAssert(bar.waitForExistence(timeout: 5), "no \(menu) menu")
        bar.click()
        let entry = bar.menuItems[item]
        XCTAssert(entry.waitForExistence(timeout: 3), "the \(menu) menu has no \(item)")
        XCTAssert(entry.isEnabled, "\(menu) > \(item) is disabled")
        entry.click()
    }

    /// `menu` > `item` is disabled, and hovering it shows `help`.
    @MainActor private func expectDisabled(_ item: String, in menu: String, help: String, _ photo: Journey) {
        let bar = photo.app.menuBars.firstMatch.menuBarItems[menu]
        XCTAssert(bar.waitForExistence(timeout: 5), "no \(menu) menu")
        bar.click()
        let entry = bar.menuItems[item]
        XCTAssert(entry.waitForExistence(timeout: 3), "the \(menu) menu has no \(item)")
        XCTAssertFalse(entry.isEnabled, "\(menu) > \(item) is enabled on an adjustment layer")
        entry.hover()
        let said = photo.app.helpTags.matching(NSPredicate(format: "label CONTAINS %@ OR title CONTAINS %@", help, help)).firstMatch
        XCTAssert(said.waitForExistence(timeout: 5), "\(menu) > \(item) doesn't say \(help)")
        photo.press(.escape)
        _ = photo.app.menus.firstMatch.waitForNonExistence(timeout: 2)
    }

    /// The open panel shows Drop Shadow and Stroke on.
    @MainActor private func expectStyled(_ photo: Journey, _ what: String) {
        XCTAssert(photo.element("suite.style.panel").waitForExistence(timeout: 5), "\(what): no panel (suite.style.panel)")
        let shadow = toggle("dropShadow", photo), stroke = toggle("stroke", photo)
        XCTAssert(waitUntil { self.isOn(shadow) && self.isOn(stroke) }, "\(what) doesn't show Drop Shadow and Stroke on")
    }

    // MARK: - Reading

    /// The panel's switch for `kind` (StyleKind's raw value).
    @MainActor private func toggle(_ kind: String, _ photo: Journey) -> XCUIElement {
        let id = "suite.style.toggle.\(kind)"
        let found = photo.element(id)
        XCTAssert(found.waitForExistence(timeout: 5), "the panel has no \(id)")
        return found
    }

    /// The first `type` control in `panel` labelled `label`.
    @MainActor private func control(_ type: XCUIElement.ElementType, _ label: String, in panel: XCUIElement) -> XCUIElement {
        panel.descendants(matching: type).matching(NSPredicate(format: "label == %@ OR title == %@", label, label)).firstMatch
    }

    @MainActor private func isOn(_ toggle: XCUIElement) -> Bool {
        guard toggle.exists else { return false }
        return (toggle.value as? Int) == 1 || (toggle.value as? String) == "1" || (toggle.value as? Bool) == true
    }

    /// Waits for the button titled `title`, such as the window toolbar's "Undo Change Layer Style".
    @MainActor private func expect(_ title: String, _ photo: Journey, _ message: String) {
        XCTAssert(photo.app.buttons[title].waitForExistence(timeout: 5), "\(message) (no \(title) button)")
    }

    /// The first .ora in `folder` within ten seconds.
    private func waitForFile(in folder: URL) -> URL? {
        for _ in 0..<20 {
            let files = (try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            if let ora = files.first(where: { $0.pathExtension == "ora" }) { return ora }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return nil
    }

    /// Whether `condition` holds within five seconds.
    @MainActor private func waitUntil(_ condition: () -> Bool) -> Bool {
        for _ in 0..<10 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.5)
        }
        return condition()
    }
}
