// HaloJourneyTests+Inspector.swift: H-J6, keying TRANSFORM from the
// inspector (layer-keys, LK-13; docs/blueprints/halo/features/layer-keys.md,
// Journey steps 2). On `-HaloFixture keyed` (Bounce: Ball keyed on x at 0
// and 24 and opacity at 0 and 12, and Floor) it selects Ball, whose lane
// reads "3 keyframes", animates Rotation at 6, finds it Animated at 20,
// keys it there with a drag on the bar, steps it with → and Shift-→
// (QB-F4), types `abc` (kept: the caption waits for #783), finds the lane at
// "6 keyframes" (0, 6, 12, 20, 24, 47), then adds an Opacity key with the
// diamond. The playhead moves from the keys: clicking Ball's name in the
// timeline focuses it, then Home and →, read on the status timecode. A
// KeyframeButton's stopwatch and diamond share `halo.inspector.key.<raw>`,
// so both are found by label ("Animate Rotation", "Add Key, Opacity") and
// the stopwatch's value is the key state. The Rotation bar is
// `halo.inspector.row.rotation`, a slider whose value is the row's text
// ("12°") or its position, both in degrees. A lane is the timeline element
// labelled with the layer's name; its key count is read from its
// `halo.timeline.keys` readout (HaloJourneyTests+Readouts.swift). Undo stays
// history-files': Edit's "Undo Add Key" item is only looked up, never
// pressed. One shot per step, `halo-inspector-<step>`. The name sorts
// before testScrubTheTimeline, which must stay the class's last test.
import XCTest

extension HaloJourneyTests {
    /// H-J6: animate, scrub, drag, step, type and key from the inspector.
    @MainActor func testInspectorKeysTransform() {
        let halo = Journey("Halo", self, arguments: ["-HaloFixture", "keyed", "-HaloWindowSize", "1000x640"])
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")

        // 1. Select Ball: its lane reads 3 keyframes (x at 0, 24; opacity at 0, 12).
        let ballRow = halo.element("halo.layer.row.comp-1-layer-2")
        XCTAssert(ballRow.waitForExistence(timeout: 10), "no Ball row (halo.layer.row.comp-1-layer-2)")
        ballRow.click()
        XCTAssert(inspectorHeader("Ball", halo).waitForExistence(timeout: 5), "clicking the Ball row didn't select Ball")
        expectLane("Ball", keys: 3, halo)

        // 2. Scrub to 6 and click Animate Rotation: keyed at this frame.
        scrubFromTheKeys(to: 6, halo)
        let animateRotation = keyButton("Animate Rotation", halo)
        XCTAssert(animateRotation.waitForExistence(timeout: 5), "no Animate Rotation button")
        animateRotation.click()
        expectKeyState("Animate Rotation", "Keyed at this frame", halo)
        halo.shot("inspector-animate-rotation")

        // 3. Scrub to 20: Animated, no key here.
        scrubFromTheKeys(to: 20, halo)
        expectKeyState("Animate Rotation", "Animated", halo)

        // 4. Drag the Rotation bar right: a key at 20.
        let before = rotation(halo)
        halo.drag(on: "halo.inspector.row.rotation", from: CGVector(dx: 0.3, dy: 0.5), to: CGVector(dx: 0.7, dy: 0.5))
        expectKeyState("Animate Rotation", "Keyed at this frame", halo)
        XCTAssert(waitUntil { (self.rotation(halo) ?? 0) > (before ?? 0) }, "dragging the bar right didn't raise Rotation")
        halo.shot("inspector-scrub-rotation")

        // 5. Focus the bar (a click opens its field, Return closes it unchanged
        // and keeps the focus), then →, → and Shift-→: +1, +1, +10.
        openRotationField(halo)
        halo.press(.return)
        XCTAssert(waitUntil { !self.typingField(halo).exists }, "Return didn't close the Rotation field")
        guard let start = rotation(halo) else {
            return XCTFail("the Rotation bar reads no number: \(String(describing: rotationBar(halo).value))")
        }
        // Each press with its modifiers and the total step from `start`.
        let presses: [(XCUIElement.KeyModifierFlags, Double)] = [([], 1), ([], 2), (.shift, 12)]
        for (modifiers, total) in presses {
            halo.press(.rightArrow, modifiers)
            let stepped = waitUntil { self.rotation(halo) == start + total }
            // Which element has the keyboard, when the arrow went elsewhere.
            if !stepped { halo.attachTree(as: "inspector-arrow-keys-tree") }
            XCTAssert(stepped, "Rotation reads \(String(describing: rotation(halo))), not \(start + total) after the arrows")
        }
        halo.shot("inspector-arrow-keys")

        // 6. Type abc and press Return: the value is kept (no caption yet, #783).
        let kept = rotation(halo)
        openRotationField(halo)
        halo.press(character: "a", .command)
        typingField(halo).typeText("abc")
        halo.press(.return)
        XCTAssert(waitUntil { !self.typingField(halo).exists }, "Return didn't close the Rotation field")
        XCTAssertEqual(rotation(halo), kept, "typing abc changed Rotation")
        halo.shot("inspector-typed-abc")

        // 7. Ball's lane reads 6 keyframes: 0, 6, 12, 20, 24, 47.
        expectLane("Ball", keys: 6, halo)

        // 8. Add Key, Opacity at 20: keyed here, and Edit holds Undo Add Key.
        let addOpacity = keyButton("Add Key, Opacity", halo)
        XCTAssert(addOpacity.waitForExistence(timeout: 5), "no Add Key, Opacity button (Opacity isn't Animated at 20)")
        addOpacity.click()
        expectKeyState("Animate Opacity", "Keyed at this frame", halo)
        expectEditItem("Undo Add Key", halo)
        halo.shot("inspector-add-key-opacity")
    }

    // MARK: - Inspector helpers

    /// Clicks `name`'s title in the timeline (selects it and focuses the
    /// timeline, as H-J3's lane click), then Home and → `frame` times.
    @MainActor private func scrubFromTheKeys(to frame: Int, _ halo: Journey) {
        let title = halo.app.buttons.matching(
            NSPredicate(format: "identifier == 'halo.timeline.track' AND label == 'Ball'")).firstMatch
        XCTAssert(title.waitForExistence(timeout: 5), "no Ball track title in the timeline")
        title.click()
        halo.press(.home)
        for _ in 0..<frame { halo.press(.rightArrow) }
        // Bounce runs at 24 fps, so frames under 24 read as the last field.
        let timecode = String(format: "00:00:00:%02d", frame)
        let staticText = NSNumber(value: XCUIElement.ElementType.staticText.rawValue)
        let predicate = NSPredicate(
            format: "label BEGINSWITH %@ OR (elementType == %@ AND value BEGINSWITH %@)", timecode, staticText, timecode)
        let pill = halo.app.windows.firstMatch.descendants(matching: .any).matching(predicate).firstMatch
        XCTAssert(pill.waitForExistence(timeout: 5), "the status timecode doesn't read \(timecode)")
    }

    /// The inspector header whose label contains `text`.
    @MainActor private func inspectorHeader(_ text: String, _ halo: Journey) -> XCUIElement {
        halo.app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == 'halo.inspector.header' AND label CONTAINS %@", text)).firstMatch
    }

    /// `layer`'s lane in the timeline reads "`keys` keyframes" within three
    /// seconds: its `halo.timeline.keys` readout (the lane's value reads empty, #262).
    @MainActor private func expectLane(_ layer: String, keys: Int, _ halo: Journey) {
        let expected = "\(keys) keyframes"
        func values() -> [String] { halo.laneKeys(layer) }
        XCTAssert(waitUntil { values().contains(expected) }, "\(layer)'s lane reads \(values()), not \(expected)")
    }

    /// The KeyframeButton part labelled `label` ("Animate Rotation", "Add Key, Opacity").
    @MainActor private func keyButton(_ label: String, _ halo: Journey) -> XCUIElement {
        halo.element("suite.inspector").buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    /// The stopwatch `label` reads `state` within three seconds.
    @MainActor private func expectKeyState(_ label: String, _ state: String, _ halo: Journey) {
        let button = keyButton(label, halo)
        XCTAssert(
            waitUntil { (button.value as? String) == state },
            "\(label) reads \(String(describing: button.value)), not \(state)")
    }

    /// The Rotation bar.
    @MainActor private func rotationBar(_ halo: Journey) -> XCUIElement {
        halo.element("halo.inspector.row.rotation")
    }

    /// The Rotation bar's value in degrees: a number, or the first number in
    /// its text ("12°", "−30°", "12 degrees"); nil when it has neither.
    @MainActor private func rotation(_ halo: Journey) -> Double? {
        let value = rotationBar(halo).value
        if let number = value as? NSNumber { return number.doubleValue }
        guard let text = value as? String else { return nil }
        let plain = text.replacingOccurrences(of: "\u{2212}", with: "-").replacingOccurrences(of: ",", with: "")
        guard let range = plain.range(of: #"-?[0-9]+(\.[0-9]+)?"#, options: .regularExpression) else { return nil }
        return Double(plain[range])
    }

    /// The bar's typing field, under the inspector while it is open.
    @MainActor private func typingField(_ halo: Journey) -> XCUIElement {
        halo.element("suite.inspector").textFields.firstMatch
    }

    /// Clicks the Rotation bar, which opens its typing field.
    @MainActor private func openRotationField(_ halo: Journey) {
        let bar = rotationBar(halo)
        XCTAssert(bar.waitForExistence(timeout: 5), "no Rotation bar (halo.inspector.row.rotation)")
        bar.click()
        XCTAssert(typingField(halo).waitForExistence(timeout: 5), "clicking the Rotation bar opened no field")
    }

    /// The Edit menu holds an item titled `title`; the menu is closed again.
    @MainActor private func expectEditItem(_ title: String, _ halo: Journey) {
        let edit = halo.app.menuBars.firstMatch.menuBarItems["Edit"]
        XCTAssert(edit.waitForExistence(timeout: 5), "no Edit menu")
        edit.click()
        let item = edit.menus.firstMatch.children(matching: .menuItem)[title]
        XCTAssert(item.waitForExistence(timeout: 3), "the Edit menu has no \(title)")
        halo.press(.escape)
        XCTAssert(halo.menusClosed(), "a menu stayed open after Escape")
    }

    /// Whether `condition` holds within three seconds.
    @MainActor private func waitUntil(_ condition: () -> Bool) -> Bool {
        for _ in 0..<15 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }
}
