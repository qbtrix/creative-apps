// SuiteJourneyTests+Inspector.swift: SJ11 to SJ15, IC-13 (packet
// docs/blueprints/suiteui/features/inspector-controls.md, Journey steps 1-5;
// blueprint suiteui 4.2). They drive the gallery's `inspector` page (IC-12)
// inside Library, by the identifiers the page opts into
// (`suite.gallery.inspector.<row>`, `suite.inspector.section.<title>`), and
// read `suite.gallery.log`, whose label and value are its lines: every
// onChange writes `<what>` and every onEnd `<what> ends <n>`, n counting every
// onEnd so far, so "one gesture, one end" (QB-F3) is n growing by exactly one.
// A drag's first 2 pt only tell it from a click (ScrubField), so a drag's
// value is checked within that slack and its snapping, not to the point. The
// disabled rows' reasons are read from `suite.controls` (`-SuitePerfProbe`),
// since XCUITest can't read a tooltip; the hover is still shot. SJ15 reads
// the Onion chip's `fade-start`/`fade-end` marks from `suite.perf` (QB-S9).
// SwiftUI values can read "" in XCUITest (#262), so text falls back to the
// label.
import XCTest

extension SuiteJourneyTests {
    private static let inspectorArguments = ["-SuiteGallery", "inspector", "-SuitePerfProbe"]
    private static let inspectorLocked = "Locked while the gallery shows a disabled row."

    /// SJ11: the Rotation bar drags, ⇧-drags, ⌥-drags, types, refuses `abc`, cancels and steps; Skew is locked.
    @MainActor func testBarSliderScrubTypeAndStep() throws {
        let gallery = try inspectorOpen()
        let log = gallery.element("suite.gallery.log")
        let rotation = inspectorFind("suite.gallery.inspector.rotation", gallery)
        let start = rotation.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))

        // 1. Drag 40 pt right: one step a point, less the 2 pt that tell a drag from a click.
        var ends = inspectorEnds(log)
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 40, dy: 0)))
        ends = expectInspectorEnd("rotation ", ends, log)
        let dragged = inspectorNumber("rotation ", log)
        XCTAssert((30...40).contains(dragged), "a 40 pt drag set Rotation to \(dragged)°, not about 40°")
        gallery.shot("inspector-rotation-dragged")

        // 2. ⇧-drag 4 pt: ten steps a point, snapped to tens.
        XCUIElement.perform(withKeyModifiers: .shift) {
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 4, dy: 0)))
        }
        ends = expectInspectorEnd("rotation ", ends, log)
        let coarse = inspectorNumber("rotation ", log)
        XCTAssert(coarse > dragged && coarse <= dragged + 50, "the ⇧-drag moved Rotation from \(dragged)° to \(coarse)°")
        XCTAssertEqual(coarse.truncatingRemainder(dividingBy: 10), 0, "the ⇧-drag left \(coarse)°, not a multiple of 10")

        // 3. ⌥-drag 10 pt: a tenth of a step a point, so the shown value moves by at most one.
        XCUIElement.perform(withKeyModifiers: .option) {
            start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 10, dy: 0)))
        }
        ends = expectInspectorEnd("rotation ", ends, log)
        let fine = inspectorNumber("rotation ", log)
        XCTAssert((coarse...coarse + 1).contains(fine), "the ⌥-drag moved Rotation from \(coarse)° to \(fine)°, not by ≤ 1")

        // 4. Click the value, type 72, Return; then `abc` keeps 72 (still one end); then 9 and Escape commit nothing.
        inspectorType("72", into: rotation, gallery)
        gallery.press(.return)
        ends = expectInspectorEnd("rotation 72°", ends, log)
        inspectorType("abc", into: rotation, gallery)
        gallery.shot("inspector-rotation-typing")
        gallery.press(.return)
        ends = expectInspectorEnd("rotation 72°", ends, log)
        inspectorType("9", into: rotation, gallery)
        let before = inspectorText(log)
        gallery.press(.escape)
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(inspectorText(log), before, "Escape after typing 9 changed the log")
        XCTAssert(inspectorWait { self.inspectorText(rotation).contains("72") }, "Rotation reads \(inspectorText(rotation)) after Escape, not 72")

        // 5. The bar has the keys again: → → ⇧→ End Home give 73, 74, 84, the maximum, the minimum.
        let steps: [(XCUIKeyboardKey, XCUIElement.KeyModifierFlags, String)] = [
            (.rightArrow, [], "73°"), (.rightArrow, [], "74°"), (.rightArrow, .shift, "84°"), (.end, [], "180°"), (.home, [], "-180°"),
        ]
        for (key, flags, value) in steps {
            gallery.press(key, flags)
            ends = expectInspectorEnd("rotation \(value)", ends, log)
        }
        gallery.shot("inspector-rotation-stepped")

        // 6. Skew is disabled: its entry says why, and a drag on it writes nothing.
        let skew = inspectorFind("suite.gallery.inspector.skew", gallery)
        let entry = gallery.controls()?.controls.first { $0.id == "suite.gallery.inspector.skew" }
        XCTAssertEqual(entry?.enabled, false, "Skew is listed enabled in suite.controls")
        XCTAssertEqual(entry?.reason, Self.inspectorLocked, "Skew's reason in suite.controls")
        skew.hover()
        gallery.shot("inspector-skew-locked")
        let locked = inspectorText(log)
        let skewMiddle = skew.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        skewMiddle.press(forDuration: 0.1, thenDragTo: skewMiddle.withOffset(CGVector(dx: 30, dy: 0)))
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(inspectorText(log), locked, "dragging the disabled Skew row changed the log")
    }

    /// SJ12: the X field drags 30 then ↑ (#718); FILL's hex takes FF3B30 and refuses zz; a panel pick ends once.
    @MainActor func testExactFieldAndColorRowEnd() throws {
        let gallery = try inspectorOpen()
        let log = gallery.element("suite.gallery.log")
        let x = inspectorFind("suite.gallery.inspector.x", gallery)

        // 1. Drag X 30 pt right, then ↑: +30 (less the 2 pt slack), then +1, one end each.
        var ends = inspectorEnds(log)
        let start = x.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 30, dy: 0)))
        ends = expectInspectorEnd("x ", ends, log)
        let dragged = inspectorNumber("x ", log)
        XCTAssert((20...30).contains(dragged), "a 30 pt drag set X to \(dragged) px, not about 30")
        gallery.press(.upArrow)
        ends = expectInspectorEnd("x \(dragged.isFinite ? Int(dragged) + 1 : 0) px", ends, log)
        gallery.shot("inspector-x")

        // 2. FILL's hex: FF3B30 and Return logs the color and one end; zz and Return keeps it, still one end.
        let hex = gallery.app.textFields.matching(NSPredicate(
            format: "identifier == %@ OR label == %@ OR placeholderValue == %@",
            "suite.gallery.inspector.fill", "Fill Hex", "Fill Hex")).firstMatch
        XCTAssert(hex.waitForExistence(timeout: 5), "no Fill Hex field")
        inspectorType("FF3B30", into: hex, gallery)
        gallery.press(.return)
        ends = expectInspectorEnd("color #FF3B30", ends, log)
        inspectorType("zz", into: hex, gallery)
        gallery.press(.return)
        ends = expectInspectorEnd("color #FF3B30", ends, log)
        XCTAssert(inspectorWait { self.inspectorText(hex).uppercased().contains("FF3B30") }, "Fill Hex reads \(inspectorText(hex)) after zz")
        gallery.shot("inspector-fill-hex")

        // 3. Pick in the system color panel: changes log no end until the panel closes, then exactly one.
        let well = gallery.app.colorWells.firstMatch
        XCTAssert(well.waitForExistence(timeout: 5), "no Fill color well")
        well.click()
        let panel = inspectorColorPanel(gallery)
        XCTAssert(panel.waitForExistence(timeout: 5), "clicking the Fill well opened no Colors panel")
        for spot in [CGVector(dx: 0.3, dy: 0.3), CGVector(dx: 0.6, dy: 0.35)] {
            panel.coordinate(withNormalizedOffset: spot).click()
        }
        let picked = { self.inspectorLast(log) }
        XCTAssert(inspectorWait { picked().hasPrefix("color #") && picked() != "color #FF3B30 ends \(ends)" },
                  "a pick in the Colors panel logged \(picked())")
        XCTAssertFalse(picked().contains(" ends "), "a panel pick ended before the panel closed: \(picked())")
        gallery.shot("inspector-fill-panel")
        panel.buttons[XCUIIdentifierCloseWindow].click()
        ends = expectInspectorEnd("color #", ends, log)
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertEqual(inspectorEnds(log), ends, "closing the Colors panel ended more than once")
    }

    /// SJ13: TRANSFORM collapses and expands; Reset shows only while it differs; Cap, the checkbox, the locked action.
    @MainActor func testSectionsPickersTogglesAndReset() throws {
        let gallery = try inspectorOpen()
        let log = gallery.element("suite.gallery.log")
        let header = inspectorFind("suite.inspector.section.transform", gallery)
        let reset = gallery.element("suite.inspector.section.transform.reset")
        let rotation = inspectorFind("suite.gallery.inspector.rotation", gallery)

        // 1. The header collapses the section and expands it again.
        header.click()
        XCTAssert(inspectorWait { self.inspectorText(header) == "Collapsed" && !rotation.exists }, "TRANSFORM didn't collapse")
        gallery.shot("inspector-transform-collapsed")
        header.click()
        XCTAssert(inspectorWait { self.inspectorText(header) == "Expanded" && rotation.exists }, "TRANSFORM didn't expand")

        // 2. Reset shows only once Rotation differs; its hit frame is ≥ 20 × 20 pt and over no other control.
        XCTAssertFalse(reset.exists, "Reset shows while TRANSFORM is at its defaults")
        let ends = inspectorEnds(log)
        inspectorType("15", into: rotation, gallery)
        gallery.press(.return)
        _ = expectInspectorEnd("rotation 15°", ends, log)
        XCTAssert(reset.waitForExistence(timeout: 5), "no Reset once Rotation reads 15°")
        XCTAssert(reset.frame.width >= 20 && reset.frame.height >= 20, "Reset's hit frame is \(reset.frame.size), under 20 × 20")
        for id in ["suite.inspector.section.transform", "suite.gallery.inspector.rotation",
                   "suite.gallery.inspector.keyframe-rotation", "suite.gallery.inspector.x"] {
            let overlap = reset.frame.intersection(gallery.element(id).frame)
            XCTAssert(overlap.isNull || overlap.width * overlap.height < 0.5, "Reset overlaps \(id)")
        }
        gallery.shot("inspector-transform-reset")
        reset.click()
        expectInspectorLog("reset transform", log)
        XCTAssert(inspectorWait { !reset.exists }, "Reset stayed after resetting TRANSFORM")

        // 3. Cap: choose Round; the picker reads it.
        let cap = inspectorFind("suite.gallery.inspector.cap", gallery)
        cap.click()
        let round = gallery.app.menuItems["Round"]
        XCTAssert(round.waitForExistence(timeout: 5), "the Cap picker's menu has no Round")
        round.click()
        expectInspectorLog("cap round", log)
        XCTAssert(inspectorWait { (self.inspectorText(cap) + " " + cap.label).contains("Round") }, "Cap reads \(inspectorText(cap))")

        // 4. The Snap to Pixels checkbox toggles.
        let snap = inspectorFind("suite.gallery.inspector.snap", gallery)
        let was = inspectorText(snap)
        snap.click()
        expectInspectorLog("snap on", log)
        XCTAssert(inspectorWait { self.inspectorText(snap) != was }, "the checkbox's value stayed \(was)")

        // 5. Convert to Path is disabled and says why.
        let convert = inspectorFind("suite.gallery.inspector.action-convert", gallery)
        XCTAssertFalse(convert.isEnabled, "Convert to Path is enabled")
        let entry = gallery.controls()?.controls.first { $0.id == "suite.gallery.inspector.action-convert" }
        XCTAssertEqual(entry?.enabled, false, "Convert to Path is listed enabled")
        XCTAssertEqual(entry?.reason, "The gallery has no shape to convert.", "Convert to Path's reason")
        convert.hover()
        gallery.shot("inspector-style")
    }

    /// SJ14: the stopwatch adds a key, the page sets animated and keyed-here, the diamond removes it; the row keeps its width.
    @MainActor func testKeyframeButtonStates() throws {
        let gallery = try inspectorOpen()
        let log = gallery.element("suite.gallery.log")
        let rotation = inspectorFind("suite.gallery.inspector.rotation", gallery)
        let stopwatch = inspectorFind("suite.gallery.inspector.keyframe-rotation", gallery)
        let diamond = gallery.element("suite.gallery.inspector.keyframe-rotation.diamond")
        XCTAssertEqual(inspectorText(stopwatch), "Not animated", "the stopwatch at rest")
        // The row's edges: the bar's leading edge and the stopwatch's (the diamond's slot is kept in every state).
        let row = { (rotation.frame.minX, stopwatch.frame.minX) }
        let rest = row()
        gallery.shot("inspector-key-idle")

        // 1. Click the stopwatch: a key here.
        stopwatch.click()
        expectInspectorLog("key add, Keyed at this frame", log)
        XCTAssert(inspectorWait { self.inspectorText(stopwatch) == "Keyed at this frame" }, "the stopwatch reads \(inspectorText(stopwatch))")
        // 2. The page's switches: animated, then keyed here.
        inspectorFind("suite.gallery.inspector.animated", gallery).click()
        expectInspectorLog("state, Animated", log)
        XCTAssert(inspectorWait { self.inspectorText(stopwatch) == "Animated" }, "the stopwatch reads \(inspectorText(stopwatch))")
        XCTAssert(diamond.waitForExistence(timeout: 5), "no diamond while animated")
        XCTAssertEqual(diamond.label, "Add Key, Rotation", "the diamond while animated")
        let animated = row()
        gallery.shot("inspector-key-animated")
        inspectorFind("suite.gallery.inspector.keyed-here", gallery).click()
        expectInspectorLog("state, Keyed at this frame", log)
        XCTAssert(inspectorWait { diamond.label == "Remove Key, Rotation" }, "the diamond reads \(diamond.label) when keyed here")
        let keyed = row()
        gallery.shot("inspector-key-keyed")
        // 3. Click the diamond: the key goes, the property stays animated.
        diamond.click()
        expectInspectorLog("key remove, Animated", log)
        XCTAssert(inspectorWait { self.inspectorText(stopwatch) == "Animated" }, "the stopwatch reads \(inspectorText(stopwatch))")
        for (name, edges) in [("animated", animated), ("keyed here", keyed)] {
            XCTAssertEqual(edges.0, rest.0, accuracy: 0.5, "the Rotation row's leading edge moved when \(name)")
            XCTAssertEqual(edges.1, rest.1, accuracy: 0.5, "the stopwatch, the row's trailing part, moved when \(name)")
        }
    }

    /// SJ15: one preset on at a time, → and Space move it; Onion on then off, each click one fade pair (QB-S9).
    @MainActor func testPresetsAndChips() throws {
        let gallery = try inspectorOpen()
        let log = gallery.element("suite.gallery.log")
        let presets = ["linear", "ease-in", "ease-out", "ease-in-out"].map {
            inspectorFind("suite.gallery.inspector.preset-\($0)", gallery)
        }
        let on = { presets.filter(\.isSelected).count }

        // 1. Click Ease Out: it alone is on. → then Space picks its neighbour, Ease In Out.
        presets[2].click()
        expectInspectorLog("preset ease-out", log)
        XCTAssert(inspectorWait { presets[2].isSelected && on() == 1 }, "Ease Out isn't the one preset on")
        gallery.press(.rightArrow)
        gallery.press(.space)
        expectInspectorLog("preset ease-in-out", log)
        XCTAssert(inspectorWait { presets[3].isSelected && on() == 1 }, "Ease In Out isn't the one preset on after → Space")
        gallery.shot("inspector-presets")

        // 2. Onion twice, with the page's Reduce Motion off, then twice with it on: one pair per click.
        let onion = inspectorFind("suite.gallery.inspector.chip-onion", gallery)
        let refresh = gallery.perf()?.refreshInterval ?? 1.0 / 60
        for reduced in [false, true] {
            if reduced {
                inspectorFind("suite.gallery.inspector.reduce-motion", gallery).click()
                Thread.sleep(forTimeInterval: 0.5)
            }
            for turnOn in [true, false] {
                let before = inspectorFades(gallery).count
                onion.click()
                expectInspectorLog("chip onion \(turnOn ? "on" : "off")", log)
                XCTAssert(inspectorWait { onion.isSelected == turnOn }, "Onion's isSelected isn't \(turnOn)")
                Thread.sleep(forTimeInterval: 0.5)
                let added = Array(inspectorFades(gallery).dropFirst(before))
                XCTAssertEqual(added.map(\.name), ["fade-start", "fade-end"], "one Onion click's chip marks")
                guard added.count == 2, let first = added.first, let last = added.last else { continue }
                let gap = last.time - first.time, want = reduced ? 0 : 0.14
                XCTAssertEqual(gap, want, accuracy: refresh, "Onion's fade took \(gap) s, Reduce Motion \(reduced)")
            }
            gallery.shot(reduced ? "inspector-onion-reduced" : "inspector-onion")
        }
    }

    // MARK: Helpers

    /// Library on the gallery's `inspector` page, with its log showing.
    @MainActor private func inspectorOpen() throws -> Journey {
        let gallery = Journey("Library", self, name: "suiteui", arguments: Self.inspectorArguments)
        XCTAssert(gallery.element("suite.gallery.inspector").waitForExistence(timeout: 30), "no inspector page")
        XCTAssert(gallery.element("suite.gallery.log").waitForExistence(timeout: 10), "no suite.gallery.log on the inspector page")
        return gallery
    }

    /// The element `id`, which must show within five seconds.
    @MainActor private func inspectorFind(_ id: String, _ gallery: Journey) -> XCUIElement {
        let element = gallery.element(id)
        XCTAssert(element.waitForExistence(timeout: 5), "no \(id) on the inspector page")
        return element
    }

    /// Clicks `element`'s middle (a field opens typing), selects what it shows and types `text`; no Return.
    @MainActor private func inspectorType(_ text: String, into element: XCUIElement, _ gallery: Journey) {
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        Thread.sleep(forTimeInterval: 0.4)
        gallery.press(character: "a", .command)
        gallery.app.typeText(text)
    }

    /// The system Colors panel, as a window or a dialog.
    @MainActor private func inspectorColorPanel(_ gallery: Journey) -> XCUIElement {
        let titled = NSPredicate(format: "title == %@ OR label == %@ OR identifier == %@", "Colors", "Colors", "NSColorPanel")
        let window = gallery.app.windows.matching(titled).firstMatch
        return window.waitForExistence(timeout: 3) ? window : gallery.app.dialogs.matching(titled).firstMatch
    }

    /// The `chip` series' fade marks in `suite.perf`, in order.
    @MainActor private func inspectorFades(_ gallery: Journey) -> [ProbeMark] {
        (gallery.perf()?.marks ?? []).filter { $0.series == "chip" && $0.name.hasPrefix("fade-") }
    }

    /// Waits for a new end line starting `prefix` whose count is `ends` + 1; returns that count.
    @MainActor private func expectInspectorEnd(_ prefix: String, _ ends: Int, _ log: XCUIElement) -> Int {
        let line = { self.inspectorLast(log) }
        let want = " ends \(ends + 1)"
        XCTAssert(inspectorWait { line().hasPrefix(prefix) && line().hasSuffix(want) },
                  "the log's last line reads \(line()), not \(prefix)…\(want)")
        return ends + 1
    }

    /// The log's last line reads `line` within about three seconds.
    @MainActor private func expectInspectorLog(_ line: String, _ log: XCUIElement) {
        XCTAssert(inspectorWait { self.inspectorLast(log) == line }, "the log's last line reads \(inspectorLast(log)), not \(line)")
    }

    @MainActor private func inspectorLast(_ log: XCUIElement) -> String {
        inspectorText(log).split(separator: "\n").last.map(String.init) ?? ""
    }

    /// The `n` of the log's latest `ends n`, or 0 before any end.
    @MainActor private func inspectorEnds(_ log: XCUIElement) -> Int {
        for line in inspectorText(log).split(separator: "\n").reversed() {
            if let range = line.range(of: " ends "), let n = Int(line[range.upperBound...]) { return n }
        }
        return 0
    }

    /// The number after `prefix` on the log's last line (`rotation -12°` gives -12), or NaN.
    @MainActor private func inspectorNumber(_ prefix: String, _ log: XCUIElement) -> Double {
        let line = inspectorLast(log)
        guard line.hasPrefix(prefix) else { return .nan }
        return Double(line.dropFirst(prefix.count).prefix { $0.isNumber || $0 == "-" || $0 == "." }) ?? .nan
    }

    /// What an element reads: its value when it has one (a checkbox's is a number), else its label.
    @MainActor private func inspectorText(_ element: XCUIElement) -> String {
        if let number = element.value as? NSNumber { return number.stringValue }
        let value = element.value as? String ?? ""
        return value.isEmpty ? element.label : value
    }

    /// Whether `condition` holds within about three seconds.
    @MainActor private func inspectorWait(_ condition: () -> Bool) -> Bool {
        for _ in 0..<15 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }
}
