// HaloJourneyTests+Shapes.swift: J-HS, a star layer drawn by the viewer
// (shape-tools; docs/blueprints/halo/features/shape-tools.md, Journey steps).
// On `-HaloSample three-layers -HaloRenderTo <tmp>` (Intro on live services,
// 72 frames at 24 fps, 1920 × 1080) it clicks the Shape button by the viewer
// (`halo.viewer.shape`), picks Star and types Points 6 in its options
// popover (`suite.shape.chip-star`, `suite.shape.points`, typed into as
// SuiteJourneyTests+Shapes does), drags across `halo.viewer.canvas` at a
// hand's pace (as H-J5) for a new selected "Star 1" layer (the inspector
// header names it, never its undo step "Draw Star"), drags its Scale X bar (`halo.inspector.row.scaleX`, as
// H-J6 drags Rotation), then presses ⌘R at frame 0 (`halo.viewer.rendered`,
// as H-J20) and renders a half-size PNG sequence through File > Render… (as
// H-J21): `<tmp>/Intro/` holds a PNG that ImageIO decodes. HS-2 wrote it;
// HS-7 turns it on. One shot per step, `halo-shape-<step>`.
import XCTest

final class HaloShapeJourneyTests: XCTestCase {
    /// J-HS: Shape button, Star with 6 points, a drag draws the layer, Scale X stretches it, frame 0 renders.
    @MainActor func testDrawStarLayer() throws {
        let folder = FirstFive.folder("halo-shape")
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        let arguments = ["-HaloSample", "three-layers", "-HaloRenderTo", folder.path, "-HaloWindowSize", "1000x640"]
        let halo = Journey("Halo", self, arguments: arguments)
        XCTAssert(halo.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")

        // 1. The Shape button, Star, Points 6.
        let button = halo.element("halo.viewer.shape")
        XCTAssert(button.waitForExistence(timeout: 10), "no Shape button (halo.viewer.shape)")
        button.click()
        let star = halo.element("suite.shape.chip-star")
        XCTAssert(star.waitForExistence(timeout: 5), "the Shape popover has no Star chip (suite.shape.chip-star)")
        star.click()
        let points = halo.element("suite.shape.points")
        XCTAssert(points.waitForExistence(timeout: 5), "Star shows no Points row (suite.shape.points)")
        points.click()
        let inside = points.textFields.firstMatch
        let field = inside.waitForExistence(timeout: 2) ? inside : halo.app.popovers.textFields.firstMatch
        XCTAssert(field.waitForExistence(timeout: 5), "clicking Points opened no field to type in")
        field.typeKey("a", modifierFlags: .command)
        field.typeText("6\r")
        XCTAssert(
            // The row reads its value as a number or as text ("6" either way, #4222).
            FirstFive.wait(5) { "\(points.value ?? "")" == "6" }, "typing 6 left Points at \(points.value ?? "nothing")")
        halo.shot("shape-1-options")
        halo.press(.escape)

        // 2. Drag in the viewer: a new layer named by its kind, "Star 1" (not its undo step, "Draw Star"), selected.
        let canvas = halo.element("halo.viewer.canvas")
        XCTAssert(canvas.waitForExistence(timeout: 5), "no artboard (halo.viewer.canvas)")
        let from = canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.3))
        from.click(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.7)),
            withVelocity: 100, thenHoldForDuration: 0.1)
        let header = halo.app.descendants(matching: .any).matching(
            NSPredicate(
                format: "identifier == 'halo.inspector.header' AND label CONTAINS %@ AND NOT label CONTAINS %@", "Star 1", "Draw")
        ).firstMatch
        XCTAssert(
            header.waitForExistence(timeout: 5),
            "no Star layer selected: the header reads \(halo.element("halo.inspector.header").label)")
        halo.shot("shape-2-star")

        // 3. Drag its Scale X bar right: the value changes.
        let scaleX = halo.element("halo.inspector.row.scaleX")
        XCTAssert(scaleX.waitForExistence(timeout: 5), "no Scale X row (halo.inspector.row.scaleX)")
        let before = String(describing: scaleX.value)
        halo.drag(on: "halo.inspector.row.scaleX", from: CGVector(dx: 0.3, dy: 0.5), to: CGVector(dx: 0.7, dy: 0.5))
        XCTAssert(
            FirstFive.wait(5) { String(describing: scaleX.value) != before }, "dragging Scale X left it at \(before)")
        halo.shot("shape-3-scaled")

        // 4. ⌘R at frame 0, then a PNG sequence through File > Render…: a PNG is written.
        halo.press(character: "r", .command)
        XCTAssert(halo.element("halo.viewer.rendered").waitForExistence(timeout: 10), "⌘R showed no rendered frame")
        let summary = halo.element("halo.viewer.summary")
        XCTAssert(
            FirstFive.wait(3) { summary.label.hasPrefix("Frame 0:") }, "the artboard reads \(summary.label), not frame 0")
        halo.choose(menu: ["File", "Render…"])
        for id in ["halo.render.format.pngSequence", "halo.render.size.half", "halo.render.start"] {
            let control = halo.element(id)
            XCTAssert(control.waitForExistence(timeout: 10), "the Render sheet has no \(id)")
            control.click()
        }
        let png = FirstFive.file(in: folder.appending(path: "Intro", directoryHint: .isDirectory), ext: "png")
        XCTAssertNotNil(
            png.flatMap(FirstFive.pixelSize(of:)), "Render wrote no PNG that decodes into \(folder.path)/Intro")
        halo.shot("shape-4-rendered")
    }
}
