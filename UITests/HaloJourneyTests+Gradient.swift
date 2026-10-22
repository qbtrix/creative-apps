// HaloJourneyTests+Gradient.swift: HJ-G1, a radial gradient on a solid (gradient-fill HG-4;
// docs/blueprints/halo/features/gradient-fill.md, Journey steps, numbered below). On `-HaloSample empty` it adds
// Layer > New > Solid, picks Radial in FILL (`halo.inspector.fillType.radial`), sets the first stop white and the
// last black through the editor's hex field (`suite.gradient.color`, a stop picked by `suite.gradient.stop.<n>`),
// scrubs Position, renders frame 0 and undoes the last colour change in one step. The viewer is read by the label
// of `halo.viewer.summary`. Written and skipped: the fill commands are stubs until HG-7, and HG-8 turns it on, on
// live services. One shot per step, `halo-gradient-<step>`.
import XCTest

final class HaloGradientJourneyTests: XCTestCase {
    override func setUpWithError() throws {
        throw XCTSkip("waits on HG-8")
    }

    /// HJ-G1: a solid takes a radial white-to-black gradient that moves with the layer and undoes in one step.
    @MainActor func testRadialSolid() {
        let halo = Journey("Halo", self, arguments: ["-HaloSample", "empty", "-HaloWindowSize", "1000x640"])
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")

        // 1. Add a solid and pick Radial: the editor shows its stop bar.
        choose(["Layer", "New", "Solid"], halo)
        let radial = halo.element("halo.inspector.fillType.radial")
        scrollInspector(toShow: radial, halo)
        XCTAssert(radial.isEnabled, "Radial is off: \(radial.label)")
        radial.click()
        XCTAssert(halo.element("suite.gradient.bar").waitForExistence(timeout: 5), "Radial shows no stop bar")
        expectUndo("Undo Change Fill", halo)
        halo.shot("gradient-1-radial")

        // 2. The first stop white, the last black.
        setStop(0, hex: "FFFFFF", halo)
        setStop(1, hex: "000000", halo)
        expectUndo("Undo Change Fill", halo)
        halo.shot("gradient-2-white-to-black")

        // 3. Scrub Position (X): the gradient moves with the layer.
        let position = halo.element("halo.inspector.row.x")
        scrollInspector(toShow: position, halo)
        position.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: position.coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5)))
        halo.shot("gradient-3-moved")

        // 4. Render frame 0 (HG-6 checks the PNG's pixels): the item is enabled.
        let render = menuItem(["File", "Render Frame"], halo)
        XCTAssert(render.isEnabled, "Render Frame is disabled")
        halo.press(.escape)

        // 5. Undo: the last colour change goes, in one step; the fill is still radial.
        halo.press(character: "z", .command)
        XCTAssert(halo.element("suite.gradient.bar").exists, "one undo took the gradient away")
        halo.shot("gradient-5-undo")
    }

    /// Picks stop `index` and types `hex` into the editor's hex field.
    @MainActor private func setStop(_ index: Int, hex: String, _ halo: Journey) {
        let stop = halo.element("suite.gradient.stop.\(index)")
        XCTAssert(stop.waitForExistence(timeout: 5), "no stop \(index)")
        stop.click()
        let field = halo.app.textFields.matching(NSPredicate(
            format: "identifier == %@ OR label == %@", "suite.gradient.color", "Color Hex")).firstMatch
        XCTAssert(field.waitForExistence(timeout: 5), "no gradient Color Hex field")
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        halo.press(character: "a", .command)
        halo.app.typeText(hex)
        halo.press(.return)
    }

    /// Scrolls the inspector (`suite.inspector`) until `element` lies whole inside it.
    @MainActor private func scrollInspector(toShow element: XCUIElement, _ halo: Journey) {
        let inspector = halo.element("suite.inspector")
        XCTAssert(inspector.waitForExistence(timeout: 5), "no inspector (suite.inspector)")
        XCTAssert(element.waitForExistence(timeout: 5), "nothing to scroll to in the inspector")
        for _ in 0..<20 where !inspector.frame.contains(element.frame) {
            inspector.scroll(byDeltaX: 0, deltaY: element.frame.minY < inspector.frame.minY ? 40 : -40)
        }
        XCTAssert(inspector.frame.contains(element.frame), "scrolling didn't bring \(element.frame) into \(inspector.frame)")
    }

    /// Opens the menu bar item `path[0]`, hovers each submenu on the way and returns the last item (the menu stays open).
    @MainActor private func menuItem(_ path: [String], _ halo: Journey) -> XCUIElement {
        var item = halo.app.menuBars.firstMatch.menuBarItems[path.first ?? ""]
        XCTAssert(item.waitForExistence(timeout: 5), "no \(path.first ?? "") menu")
        item.click()
        for (depth, title) in path.dropFirst().enumerated() {
            if depth > 0 { item.hover() }
            item = item.menus.firstMatch.children(matching: .menuItem)[title]
            XCTAssert(item.waitForExistence(timeout: 3), "no \(path.joined(separator: " > "))")
        }
        return item
    }

    /// Clicks the enabled menu item at `path`.
    @MainActor private func choose(_ path: [String], _ halo: Journey) {
        let item = menuItem(path, halo)
        XCTAssert(item.isEnabled, "\(path.joined(separator: " > ")) is disabled")
        item.click()
    }

    /// The Edit menu's first item reads `title`; the menu is closed again.
    @MainActor private func expectUndo(_ title: String, _ halo: Journey) {
        let edit = menuItem(["Edit"], halo)
        let first = edit.menus.firstMatch.children(matching: .menuItem).firstMatch
        XCTAssert(first.waitForExistence(timeout: 3), "the Edit menu shows no items")
        XCTAssertEqual(first.title, title, "the Edit menu's first item")
        halo.press(.escape)
        XCTAssert(halo.menusClosed(), "a menu stayed open after Escape")
    }
}
