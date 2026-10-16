// HaloJourneyTests+Easing.swift: H-J7, ease keys (easing, EZ-8;
// docs/blueprints/halo/features/easing.md, Journey steps). On
// `-HaloSample keyed` (Bounce on live services: Ball keyed on x at 0 and 24,
// 160 to 960 px, and on opacity at 0 and 12, and Floor) it selects Ball in
// the inspector's LAYERS list, scrolls to that list's end so EASING's rows
// and "Pick a key above." show whole above it, finds Animation > Keyframe Easing off with nothing picked, picks the
// Position X row in EASING, gives it Ease In and Out from the chips, reads
// Position X at 12 and 6, bends the curve by dragging `halo.easing.handle1`,
// gives it Hold from `halo.timeline`'s context menu, then ⌘Z three times.
// An EASING row is `halo.easing.key.<property>.<frame>`, labelled with its
// title ("Position X, frames 0–24"), its easing's title as value and selected
// while picked (HaloEasingInspector.swift); the chips are the inspector's
// buttons titled by preset, the one on carrying the selected trait. They are
// PresetGrids, lazy grids that make no element until on screen, so
// `showChips` scrolls them in before every chip query (#1411). Position
// X is the TRANSFORM row `halo.inspector.row.x`, whose value is its text
// ("560.0 px") or its number. The playhead moves from the keys: clicking
// Ball's title in the timeline focuses it, then Home and →, read on the
// status timecode, as H-J6 does. EASING sits below the inspector's fold at
// 640 pt, so the inspector is scrolled to each control before it is used,
// and each shot shows its step's end state whole (#1418).
// A disabled menu item is checked as disabled only: XCUITest doesn't read
// SwiftUI .help on menu items reliably, so its reason ("Pick a key in the
// EASING list first.") is proven by HaloModelTests'
// HaloEasingAvailabilityTests. The Model half of every step is
// HaloEasingTests.testEaseKeysJourney. One shot per step, `halo-easing-<step>`.
import XCTest

final class HaloEasingJourneyTests: XCTestCase {
    /// The `keyed` fixture's Ball, and its Position X row in EASING.
    private static let ball = "comp-1-layer-2", floor = "comp-1-layer-1"
    private static let xRow = "halo.easing.key.x.0", opacityRow = "halo.easing.key.opacity.0"
    private static let presets = ["Linear", "Ease In", "Ease Out", "Ease In and Out", "Hold"]

    /// H-J7: pick a key, ease it from the chips, the curve and the timeline, then undo.
    @MainActor func testEaseKeys() {
        let halo = Journey("Halo", self, arguments: ["-HaloSample", "keyed", "-HaloWindowSize", "1000x640"])
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")

        // 1. Select Ball in the inspector's LAYERS list: two rows, none
        // picked, "Pick a key above.". The shot sits at LAYERS' end (Floor),
        // so the note shows whole and nothing is cut at the window's edge.
        let ballRow = halo.element("halo.layer.row.\(Self.ball)")
        XCTAssert(ballRow.waitForExistence(timeout: 10), "no Ball row (halo.layer.row.\(Self.ball))")
        scrollInspector(toShow: ballRow, halo)
        ballRow.click()
        let xRow = halo.element(Self.xRow), opacityRow = halo.element(Self.opacityRow)
        XCTAssert(xRow.waitForExistence(timeout: 5), "EASING has no Position X row (\(Self.xRow))")
        scrollInspector(toShow: halo.element("halo.layer.row.\(Self.floor)"), halo)
        XCTAssertEqual(xRow.label, "Position X, frames 0–24", "the first EASING row's title")
        XCTAssertEqual(opacityRow.label, "Opacity, frames 0–12", "the second EASING row's title")
        XCTAssertFalse(xRow.isSelected, "Position X, frames 0–24 is picked before any click")
        XCTAssertFalse(opacityRow.isSelected, "Opacity, frames 0–12 is picked before any click")
        let inspector = halo.element("suite.inspector"), note = text("Pick a key above.", in: inspector)
        XCTAssert(note.waitForExistence(timeout: 5), "EASING doesn't read Pick a key above.")
        XCTAssert(inspector.frame.contains(note.frame), "Pick a key above. at \(note.frame) is cut by \(inspector.frame)")
        XCTAssert(inspector.frame.contains(xRow.frame), "the Position X row is cut by the inspector")
        halo.shot("easing-1-select-ball")

        // 2. Animation > Keyframe Easing: all five items are off.
        let items = easingMenu(halo)
        for preset in Self.presets {
            let item = items[preset]
            XCTAssert(item.waitForExistence(timeout: 3), "Keyframe Easing has no \(preset)")
            XCTAssertFalse(item.isEnabled, "Keyframe Easing > \(preset) is on with no key picked")
        }
        halo.shot("easing-2-menu-disabled", screen: true)
        closeMenu(halo)

        // 3. Click the Position X row: picked, with the chips, the curve and X1 to Y2; Linear is on.
        xRow.click()
        XCTAssert(waitFor { xRow.isSelected }, "clicking Position X, frames 0–24 didn't pick it")
        let curve = halo.element("halo.easing")
        XCTAssert(curve.waitForExistence(timeout: 5), "no easing curve (halo.easing) with a key picked")
        for row in ["x1", "y1", "x2", "y2"] {
            XCTAssert(halo.element("halo.easing.row.\(row)").exists, "no \(row.uppercased()) row (halo.easing.row.\(row))")
        }
        showChips(halo)
        expectChipOn("Linear", halo)
        scrollInspector(toShow: halo.element("halo.easing.row.y2"), halo)
        halo.shot("easing-3-pick-row")

        // 4. The Ease In and Out chip, a row of its own so its title shows
        // whole: the row reads it, and Edit names the step.
        showChips(halo)
        let easeInOut = chip("Ease In and Out", halo)
        XCTAssert(easeInOut.frame.width > chip("Linear", halo).frame.width, "Ease In and Out's chip isn't its own row")
        easeInOut.click()
        expectRow(reads: "Ease In and Out", halo)
        expectChipOn("Ease In and Out", halo)
        expectUndo("Undo Keyframe Easing", halo)
        halo.shot("easing-4-ease-in-out")

        // 5. At 12 Position X reads 560.0 px (the symmetric curve keeps the
        // midpoint); at 6 it lags the linear 360.
        scrubFromTheKeys(to: 12, halo)
        expectPositionX("560.0 px", halo)
        scrubFromTheKeys(to: 6, halo)
        XCTAssert(waitFor { (self.positionX(halo) ?? 360) < 360 }, "Position X at 6 reads \(positionXText(halo)), not below 360")
        halo.shot("easing-5-scrub")

        // 6. Drag the first handle 40 pt right: no chip is on, the row reads Custom.
        let handle = halo.element("halo.easing.handle1")
        XCTAssert(handle.waitForExistence(timeout: 5), "no first handle (halo.easing.handle1)")
        scrollInspector(toShow: curve, halo)
        let grab = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        grab.press(forDuration: 0.1, thenDragTo: grab.withOffset(CGVector(dx: 40, dy: 0)))
        expectRow(reads: "Custom", halo)
        showChips(halo)
        for preset in Self.presets {
            XCTAssertFalse(chip(preset, halo).isSelected, "the \(preset) chip is on for a custom curve")
        }
        expectUndo("Undo Keyframe Easing", halo)
        halo.shot("easing-6-drag-handle")

        // 7. Right-click the timeline and choose Hold: the row reads Hold; at 6 Position X is 160.0 px.
        let timeline = halo.element("halo.timeline")
        XCTAssert(timeline.waitForExistence(timeout: 5), "no timeline (halo.timeline)")
        timeline.rightClick()
        let hold = shownMenuItem("Hold", halo)
        XCTAssert(hold.isEnabled, "the timeline's Hold is off with a key picked")
        hold.click()
        XCTAssert(halo.menusClosed(), "the timeline's menu stayed open after Hold")
        expectRow(reads: "Hold", halo)
        scrubFromTheKeys(to: 6, halo)
        expectPositionX("160.0 px", halo)
        halo.shot("easing-7-hold")

        // 8. ⌘Z three times: Custom, Ease In and Out, Linear; the row stays picked.
        for easing in ["Custom", "Ease In and Out", "Linear"] {
            halo.press(character: "z", .command)
            expectRow(reads: easing, halo)
        }
        XCTAssert(halo.element(Self.xRow).isSelected, "undo unpicked Position X, frames 0–24")
        scrubFromTheKeys(to: 6, halo)
        expectPositionX("360.0 px", halo)
        halo.shot("easing-8-undo")
    }

    // MARK: - Helpers

    /// The first element under `root` whose label is `title`, or a static
    /// text whose value is (a plain Text reads its string as its value).
    @MainActor private func text(_ title: String, in root: XCUIElement) -> XCUIElement {
        root.descendants(matching: .any).matching(NSPredicate(format: "label == %@ OR value == %@", title, title)).firstMatch
    }

    /// The EASING chip titled `title`.
    @MainActor private func chip(_ title: String, _ halo: Journey) -> XCUIElement {
        halo.element("suite.inspector").buttons.matching(NSPredicate(format: "label == %@", title)).firstMatch
    }

    /// Scrolls the inspector until the Linear and Ease In and Out chips lie
    /// whole inside it. The chips sit just above the curve (`halo.easing`),
    /// so it scrolls toward the curve's top at the inspector's middle.
    @MainActor private func showChips(_ halo: Journey) {
        let inspector = halo.element("suite.inspector"), curve = halo.element("halo.easing")
        XCTAssert(curve.waitForExistence(timeout: 5), "no easing curve (halo.easing) under the chips")
        let first = chip("Linear", halo), last = chip("Ease In and Out", halo)
        let shown = {
            first.exists && last.exists && inspector.frame.contains(first.frame) && inspector.frame.contains(last.frame)
        }
        for _ in 0..<20 where !shown() {
            inspector.scroll(byDeltaX: 0, deltaY: curve.frame.minY > inspector.frame.midY ? -40 : 40)
        }
        XCTAssert(shown(), "the chips didn't show in the inspector (curve at \(curve.frame))")
    }

    /// The chip `title` is the one on, within three seconds.
    @MainActor private func expectChipOn(_ title: String, _ halo: Journey) {
        let on = chip(title, halo)
        XCTAssert(on.waitForExistence(timeout: 5), "no \(title) chip in EASING")
        XCTAssert(waitFor { on.isSelected }, "the \(title) chip isn't on")
    }

    /// The Position X row in EASING reads `easing` as its value within three
    /// seconds, or holds a text reading it (a value can read empty, #262).
    @MainActor private func expectRow(reads easing: String, _ halo: Journey) {
        let row = halo.element(Self.xRow)
        XCTAssert(
            waitFor { (row.value as? String) == easing || self.text(easing, in: row).exists },
            "Position X, frames 0–24 reads \(String(describing: row.value)), not \(easing)")
    }

    /// The TRANSFORM Position X row's text, or its number as text.
    @MainActor private func positionXText(_ halo: Journey) -> String {
        let value = halo.element("halo.inspector.row.x").value
        if let number = value as? NSNumber { return "\(number.doubleValue)" }
        return value as? String ?? ""
    }

    /// The TRANSFORM Position X row's number of px, nil when it reads none.
    @MainActor private func positionX(_ halo: Journey) -> Double? {
        let plain = positionXText(halo).replacingOccurrences(of: "\u{2212}", with: "-").replacingOccurrences(of: ",", with: "")
        guard let range = plain.range(of: #"-?[0-9]+(\.[0-9]+)?"#, options: .regularExpression) else { return nil }
        return Double(plain[range])
    }

    /// Position X reads `expected` ("560.0 px") within three seconds; a row
    /// that reads a bare number is compared by that number.
    @MainActor private func expectPositionX(_ expected: String, _ halo: Journey) {
        let number = Double(expected.split(separator: " ").first ?? "")
        XCTAssert(
            waitFor {
                let text = self.positionXText(halo)
                return text == expected || (Double(text) != nil && Double(text) == number)
            }, "Position X reads \(positionXText(halo)), not \(expected)")
    }

    /// Clicks Ball's title in the timeline (selects it, already selected, and
    /// focuses the timeline), then Home and → `frame` times; the status
    /// timecode reads the frame.
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

    /// Scrolls the inspector until `element` lies whole inside it, down when
    /// it sits below and up when above. `suite.inspector` is the inspector's
    /// scroll view.
    @MainActor private func scrollInspector(toShow element: XCUIElement, _ halo: Journey) {
        let inspector = halo.element("suite.inspector")
        XCTAssert(inspector.waitForExistence(timeout: 5), "no inspector (suite.inspector)")
        XCTAssert(element.waitForExistence(timeout: 5), "nothing to scroll to in the inspector")
        for _ in 0..<20 where !inspector.frame.contains(element.frame) {
            inspector.scroll(byDeltaX: 0, deltaY: element.frame.minY < inspector.frame.minY ? 40 : -40)
        }
        XCTAssert(inspector.frame.contains(element.frame), "scrolling didn't bring \(element.frame) into \(inspector.frame)")
    }

    /// Opens Animation > Keyframe Easing and returns its submenu's items (the menu stays open).
    @MainActor private func easingMenu(_ halo: Journey) -> XCUIElementQuery {
        let animation = halo.app.menuBars.firstMatch.menuBarItems["Animation"]
        XCTAssert(animation.waitForExistence(timeout: 5), "no Animation menu")
        animation.click()
        let easing = animation.menus.firstMatch.children(matching: .menuItem)["Keyframe Easing"]
        XCTAssert(easing.waitForExistence(timeout: 3), "no Animation > Keyframe Easing")
        easing.hover()
        return easing.menus.firstMatch.children(matching: .menuItem)
    }

    /// The menu item titled `title` that shows on screen: a context menu's,
    /// not a closed menu bar menu's of the same title.
    @MainActor private func shownMenuItem(_ title: String, _ halo: Journey) -> XCUIElement {
        let matches = halo.app.menuItems.matching(NSPredicate(format: "title == %@", title))
        var shown: XCUIElement?
        _ = waitFor {
            shown = matches.allElementsBoundByIndex.first { $0.isHittable }
            return shown != nil
        }
        guard let item = shown else {
            XCTFail("no \(title) item showed in the timeline's context menu")
            return matches.firstMatch
        }
        return item
    }

    /// The Edit menu's first item reads `title`; the menu is closed again.
    @MainActor private func expectUndo(_ title: String, _ halo: Journey) {
        let edit = halo.app.menuBars.firstMatch.menuBarItems["Edit"]
        XCTAssert(edit.waitForExistence(timeout: 5), "no Edit menu")
        edit.click()
        let first = edit.menus.firstMatch.children(matching: .menuItem).firstMatch
        XCTAssert(first.waitForExistence(timeout: 3), "the Edit menu shows no items")
        XCTAssertEqual(first.title, title, "the Edit menu's first item")
        closeMenu(halo)
    }

    /// Escape until no menu is up (a submenu takes two), so the next shot
    /// shows no fading menu.
    @MainActor private func closeMenu(_ halo: Journey) {
        halo.press(.escape)
        if !halo.menusClosed() { halo.press(.escape) }
        XCTAssert(halo.menusClosed(), "a menu stayed open after Escape")
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
