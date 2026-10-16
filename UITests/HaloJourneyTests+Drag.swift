// HaloJourneyTests+Drag.swift: H-J5, drag a layer in the viewer to key its
// position (layer-keys LK-12, #1036; docs/blueprints/halo/features/layer-keys.md,
// Journey steps). On `-HaloFixture keyed` (Bounce, 1920 by 1080, 24 fps: Ball
// over Floor) it selects Ball, scrubs to 12 from the keys (Home, then → twelve
// times, as H-J3 does) and drags Ball 100 px right from its position: Position X
// reads 660.0 px and `Animate Position X` "Keyed at this frame". At 0 it drags
// Floor 50 px down from its center: Position Y moves by 50 and `Animate
// Position Y` stays "Not animated". A drag in the surround changes nothing.
// Positions come from the TRANSFORM rows (`halo.inspector.row.x`, `.y`,
// sliders whose value is their position in px, 560, as H-J23 reads them),
// never the viewer summary. The artboard is
// `halo.viewer.canvas`'s frame (the drawn layers, laid out on the artboard
// as the viewer's gestures are; run 38814195169 aimed from `halo.viewer`'s
// clipped frame and pressed above Ball), and every drag is aimed in points
// from the viewer's top left. XCUITest drags
// can land a point off, so a check allows ±2 px or one point's worth of
// pixels, whichever is more (the artboard is small at the runner's size).
// Undo stays disabled until history-files lands, so the Edit menu's item
// title is read and ⌘Z is never pressed. Shots: `halo-drag-*`. The name sorts
// before testScrubTheTimeline, so H-J3 still runs last.
import XCTest

extension HaloJourneyTests {
    /// H-J5: a viewer drag keys an animated position and moves a static one.
    @MainActor func testDragLayerToKeyPosition() {
        let halo = Journey("Halo", self, arguments: ["-HaloFixture", "keyed", "-HaloWindowSize", "1000x640"])
        let steps = ViewerDragSteps(halo: halo)
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(halo.element("halo.viewer").waitForExistence(timeout: 10), "no viewer (halo.viewer)")

        // 1. Select Ball, scrub to 12 and read its position.
        let ballRow = halo.element("halo.layer.row.comp-1-layer-2")
        XCTAssert(ballRow.waitForExistence(timeout: 10), "no Ball row in the layer list")
        ballRow.click()
        steps.focusLane("Ball")
        halo.press(.home)
        for _ in 0..<12 { halo.press(.rightArrow) }
        steps.expectPlayhead("00:00:00:12")
        let ballX = steps.pixels("x"), ballY = steps.pixels("y")
        XCTAssertEqual(ballX, 560, accuracy: 0.05, "Ball's Position X at 12")
        halo.shot("drag-ball-frame-12")

        // 2. Drag Ball 100 px right from its position: a key at 12.
        steps.drag(from: (ballX, ballY), by: (100, 0))
        let tolerance = steps.tolerance()
        let movedX = steps.pixels("x")
        // Where the press landed against what the window held, when it missed.
        if abs(movedX - 660) > tolerance { halo.attachTree(as: "drag-ball-tree") }
        XCTAssertEqual(movedX, 660, accuracy: tolerance, "Ball's Position X after a 100 px drag (±\(tolerance) px)")
        steps.expectKeyState("Position X", "Keyed at this frame")
        steps.expectEditItem("Undo Move")
        halo.shot("drag-ball-keyed")

        // 3. At 0, drag Floor 50 px down from its center: its static Y moves.
        steps.focusLane("Floor")
        halo.press(.home)
        steps.expectPlayhead("00:00:00:00")
        steps.expectSelected("Floor")
        let floorX = steps.pixels("x"), floorY = steps.pixels("y")
        steps.drag(from: (floorX, floorY), by: (0, 50))
        steps.expectSelected("Floor")
        let movedY = steps.pixels("y")
        XCTAssertEqual(movedY, floorY + 50, accuracy: tolerance, "Floor's Position Y after a 50 px drag (±\(tolerance) px)")
        steps.expectKeyState("Position Y", "Not animated")
        steps.expectEditItem("Undo Move")
        halo.shot("drag-floor-static")

        // 4. A drag in the surround moves nothing and keeps Floor selected.
        steps.dragInSurround()
        steps.expectSelected("Floor")
        XCTAssertEqual(steps.pixels("y"), movedY, accuracy: 0.05, "a surround drag moved Floor")
        steps.expectEditItem("Undo Move")
        halo.shot("drag-surround")
    }
}

/// H-J5's steps over one launched Halo.
@MainActor private struct ViewerDragSteps {
    let halo: Journey

    /// The fixture's composition width in pixels.
    private static let compositionWidth: CGFloat = 1920
    /// SuiteSize.canvasInset: the surround CanvasSurface keeps on every side.
    private static let inset: CGFloat = 64

    private var viewer: XCUIElement { halo.element("halo.viewer") }

    /// Points per composition pixel, and the artboard's top left in points
    /// from the viewer's top left, read from `halo.viewer.canvas`, the drawn
    /// layers laid out on the artboard (as the viewer's gestures are). The
    /// viewer's own frame can't stand in: XCUITest reads it clipped to the
    /// content column, which isn't the region the artboard centers in.
    /// Scale 0 with no canvas.
    private func fit() -> (scale: CGFloat, origin: CGPoint) {
        let canvas = halo.element("halo.viewer.canvas")
        guard canvas.waitForExistence(timeout: 5) else { return (0, .zero) }
        let (board, frame) = (canvas.frame, viewer.frame)
        return (board.width / Self.compositionWidth, CGPoint(x: board.minX - frame.minX, y: board.minY - frame.minY))
    }

    /// The pixel slack a check allows: 2 px, or one point's worth when that is more.
    func tolerance() -> Double {
        let scale = fit().scale
        return scale > 0 ? max(2, Double(1 / scale)) : 2
    }

    /// Drags from composition pixel `start` by `delta` pixels inside the artboard.
    func drag(from start: (Double, Double), by delta: (Double, Double)) {
        XCTAssert(viewer.waitForExistence(timeout: 5), "no viewer to drag in")
        let (scale, origin) = fit()
        XCTAssertGreaterThan(scale, 0, "the viewer \(viewer.frame) leaves no room for the artboard")
        let corner = viewer.coordinate(withNormalizedOffset: .zero)
        let from = corner.withOffset(
            CGVector(dx: origin.x + CGFloat(start.0) * scale, dy: origin.y + CGFloat(start.1) * scale))
        let to = from.withOffset(CGVector(dx: CGFloat(delta.0) * scale, dy: CGFloat(delta.1) * scale))
        Self.personDrag(from, to)
    }

    /// Presses, then drags at a hand's pace (100 pt a second) and holds
    /// before letting go, so the drag arrives as many small moves. The default
    /// press-and-drag crossed Ball's 22 pt in 44 ms and Ball didn't move (run
    /// 38823293728's synthesized event).
    private static func personDrag(_ from: XCUICoordinate, _ to: XCUICoordinate) {
        from.click(forDuration: 0.1, thenDragTo: to, withVelocity: 100, thenHoldForDuration: 0.1)
    }

    /// Drags down the surround left of the artboard, half an inset from the viewer's edge.
    func dragInSurround() {
        let half = Self.inset / 2
        let from = viewer.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: half, dy: half))
        Self.personDrag(from, from.withOffset(CGVector(dx: 0, dy: half)))
    }

    /// Clicks layer `name`'s timeline lane: selects it and focuses the
    /// timeline, so Home and → reach the playhead.
    func focusLane(_ name: String) {
        let lane = halo.app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == 'halo.timeline.track' AND label == %@", name)).firstMatch
        XCTAssert(lane.waitForExistence(timeout: 5), "no \(name) lane in the timeline")
        lane.click()
        expectSelected(name)
    }

    /// The inspector header names layer `name` within five seconds.
    func expectSelected(_ name: String) {
        let header = halo.app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier == 'halo.inspector.header' AND label CONTAINS %@", name)).firstMatch
        XCTAssert(
            header.waitForExistence(timeout: 5),
            "\(name) isn't selected: the header reads \(halo.element("halo.inspector.header").label)")
    }

    /// The status timecode pill starts with `timecode` within five seconds.
    func expectPlayhead(_ timecode: String) {
        let text = NSNumber(value: XCUIElement.ElementType.staticText.rawValue)
        let pill = halo.app.windows.firstMatch.descendants(matching: .any).matching(NSPredicate(
            format: "label BEGINSWITH %@ OR (elementType == %@ AND value BEGINSWITH %@)", timecode, text, timecode
        )).firstMatch
        XCTAssert(pill.waitForExistence(timeout: 5), "the playhead isn't at \(timecode)")
    }

    /// The pixels TRANSFORM row `raw` reads, once it settles: the row is a
    /// slider (InspectorSliderRow's accessibility representation), so
    /// XCUITest reads its position in px (560), or its text ("560.0 px");
    /// 0 (and a failure) when it reads no number.
    func pixels(_ raw: String) -> Double {
        let row = halo.element("halo.inspector.row.\(raw)")
        XCTAssert(row.waitForExistence(timeout: 5), "no halo.inspector.row.\(raw)")
        var last: Double?
        for _ in 0..<10 {
            let now = (row.value as? NSNumber)?.doubleValue ?? number(in: (row.value as? String) ?? "")
            if let now, now == last { return now }
            last = now
            Thread.sleep(forTimeInterval: 0.2)
        }
        guard let last else {
            XCTFail("halo.inspector.row.\(raw) reads no number: \(String(describing: row.value)) / \(row.label)")
            return 0
        }
        return last
    }

    /// The leading number of `text` ("−12.5 px" and "-12.5 px" give −12.5).
    private func number(in text: String) -> Double? {
        let normalized = text.replacingOccurrences(of: "\u{2212}", with: "-").replacingOccurrences(of: ",", with: "")
        let digits = normalized.trimmingCharacters(in: .whitespaces).prefix { $0.isNumber || $0 == "." || $0 == "-" }
        return Double(digits)
    }

    /// The `Animate <title>` key button reads `state` within five seconds.
    func expectKeyState(_ title: String, _ state: String) {
        let button = halo.app.descendants(matching: .any).matching(
            NSPredicate(format: "label == %@", "Animate \(title)")).firstMatch
        XCTAssert(button.waitForExistence(timeout: 5), "no Animate \(title) button")
        for _ in 0..<15 where (button.value as? String) != state {
            Thread.sleep(forTimeInterval: 0.2)
        }
        XCTAssertEqual(button.value as? String, state, "Animate \(title)'s value")
    }

    /// The Edit menu holds an item titled `title`; the menu is closed again. Never presses it.
    func expectEditItem(_ title: String) {
        let edit = halo.app.menuBars.firstMatch.menuBarItems["Edit"]
        XCTAssert(edit.waitForExistence(timeout: 5), "no Edit menu")
        edit.click()
        let item = edit.menus.firstMatch.menuItems.matching(NSPredicate(format: "title == %@", title)).firstMatch
        XCTAssert(item.waitForExistence(timeout: 3), "the Edit menu has no \(title)")
        halo.press(.escape)
        halo.menusClosed()
    }
}
