// DesignJourneyTests+Transform.swift: J-DT, turn and mirror a layer on live services
// (docs/blueprints/design/features/transform.md, Journey steps). Written in DT-2 on the stubs, turned on in DT-7.
// A new file at 1024 × 768, exporting into `-DesignExportTo <tmp folder>` (no folder panel).
// 1. Draw a rectangle, Shift-drag its rotate knob a little past 15°: one "Rotate" step, Rotation
//    (`design.inspector.rotation`) reads 15.
// 2. Drag the right handle outward along the turned edge: one "Resize" step, Width grows, the turn stays 15.
// 3. Object > Flip Horizontal: one "Flip Horizontal" step, the selection box stays where it was.
// 4. Type 0 in Rotation: one "Transform" step, it reads 0; one Undo goes back to the flip and 15 (one step
//    per gesture).
// 5. ⇧⌘E, SVG, Export: the rect carries `transform="rotate(15 …)"`.
// Shots: design-transform-drawn, -turned, -grown, -flipped, -upright, -exported.
import XCTest

final class DesignTransformJourneyTests: XCTestCase {
    static let arguments = ["-DesignServices", "live", "-SuiteWindowSize", "1024x768"]
    /// The inspector's Rotation bar (DesignControlID.inspectorRotation) and Width field (`frameField` .width).
    static let rotation = "design.inspector.rotation", width = "design.inspector.width"
    /// The selection mark: the selected node's unturned frame in screen points (DesignControlID.canvasSelection).
    static let selection = "design.canvas.selection"
    /// Where the rotate knob sits above the box's top-edge midpoint, in screen points. Computed, not read:
    /// `HandleHit.centre(.rotate)` puts it `knobGap` = 2 × handleTolerance above, and handleTolerance is
    /// SuiteSpacing.s (8) / zoom, so on screen it is always 16 pt. Its hit is 8 pt either way.
    static let knobGap: CGFloat = 16

    /// J-DT steps 1 to 5: the knob turns, the handle grows along the turn, Flip mirrors, 0 stands it up, SVG says so.
    @MainActor func testRotateAndFlip() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("design-transform-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let design = Journey("Design", self, arguments: Self.arguments + ["-DesignExportTo", folder.path])
        XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        design.element("design.bar.new").click()
        XCTAssert(design.element("suite.canvas").waitForExistence(timeout: 10), "New showed no page (suite.canvas)")
        let undo = design.element("design.bar.undo")

        // 1. A rectangle well over 24 pt a side (smaller is compact: no knob), then the knob with Shift to 15°.
        design.element("suite.tools").buttons["Rectangle"].click()
        design.drag(on: "suite.canvas", from: CGVector(dx: 0.3, dy: 0.35), to: CGVector(dx: 0.55, dy: 0.55))
        XCTAssert(Self.waitForLabel(undo, "Undo Add Rectangle"), "the drag drew no rectangle (Undo reads \(undo.label))")
        let mark = design.element(Self.selection)
        XCTAssert(mark.waitForExistence(timeout: 5), "the new rectangle isn't selected (\(Self.selection))")
        let box = mark.frame
        design.shot("transform-drawn")
        let centre = CGPoint(x: box.midX, y: box.midY), reach = box.height / 2 + Self.knobGap
        // Clockwise in y-down screen space: from straight up (-90°) to -73°; Shift snaps 17° to 15°.
        XCUIElement.perform(withKeyModifiers: .shift) {
            drag(design, from: Self.point(centre, reach, -90), to: Self.point(centre, reach, -73))
        }
        XCTAssert(Self.waitForLabel(undo, "Undo Rotate"), "the knob drag made no Rotate step (Undo reads \(undo.label))")
        let rotation = control(design, Self.rotation)
        XCTAssert(rotation.waitForExistence(timeout: 5), "no Rotation bar (\(Self.rotation))")
        design.reveal(rotation)
        XCTAssert(Self.waitUntil { Self.number(rotation) == 15 }, "Shift-drag left Rotation at \(Self.text(rotation)), not 15")
        design.shot("transform-turned")

        // 2. The right handle, turned with the box, dragged 40 pt out along the turned edge (cos 15°, sin 15°).
        let width = control(design, Self.width)
        design.reveal(width)
        let before = Self.number(width) ?? 0
        drag(design, from: Self.point(centre, box.width / 2, 15), to: Self.point(centre, box.width / 2 + 40, 15))
        XCTAssert(Self.waitForLabel(undo, "Undo Resize"), "the handle drag made no Resize step (Undo reads \(undo.label))")
        XCTAssert(Self.waitUntil { (Self.number(width) ?? 0) > before + 20 }, "Width reads \(Self.text(width)), not past \(before + 20)")
        XCTAssert(Self.number(rotation) == 15, "the resize changed the turn (Rotation reads \(Self.text(rotation)))")
        design.shot("transform-grown")

        // 3. Object > Flip Horizontal mirrors about the centre: the box stays put.
        let grown = mark.frame
        design.app.menuBars.firstMatch.menuBarItems["Object"].click()
        design.app.menuItems["Flip Horizontal"].click()
        XCTAssert(Self.waitForLabel(undo, "Undo Flip Horizontal"), "Flip Horizontal made no step (Undo reads \(undo.label))")
        let flipped = mark.frame
        XCTAssert(abs(flipped.midX - grown.midX) <= 1 && abs(flipped.midY - grown.midY) <= 1 && abs(flipped.width - grown.width) <= 1,
                  "Flip Horizontal moved the box from \(grown) to \(flipped)")
        design.shot("transform-flipped")

        // 4. 0 in Rotation stands it up as one Transform step; one Undo goes back to the flip, at 15.
        design.reveal(rotation)
        rotation.click()
        let field = typingField(design, in: rotation)
        XCTAssert(field.waitForExistence(timeout: 5), "clicking Rotation opened no typing field")
        design.press(character: "a", .command)
        field.typeText("0")
        design.press(.return)
        XCTAssert(Self.waitUntil { Self.number(rotation) == 0 }, "Rotation reads \(Self.text(rotation)), not 0")
        XCTAssert(Self.waitForLabel(undo, "Undo Transform"), "typing 0 made no Transform step (Undo reads \(undo.label))")
        design.shot("transform-upright")
        undo.click()
        XCTAssert(Self.waitForLabel(undo, "Undo Flip Horizontal"), "one Undo took more than the 0 (Undo reads \(undo.label))")
        XCTAssert(Self.waitUntil { Self.number(rotation) == 15 }, "Undo left Rotation at \(Self.text(rotation)), not 15")

        // 5. The SVG writes the turn about the centre.
        exportSVG(design)
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        let file = try XCTUnwrap(files.first { $0.pathExtension == "svg" }, "the export wrote no SVG into \(folder.path)")
        let svg = try String(contentsOf: file, encoding: .utf8)
        XCTAssert(svg.contains(#"transform="rotate(15 "#), "\(file.lastPathComponent) carries no rotate(15 …): \(svg.prefix(400))")
        design.shot("transform-exported")
    }

    // MARK: - Steps

    /// The point `radius` from `centre` at `degrees`, clockwise from the right in y-down screen space.
    private static func point(_ centre: CGPoint, _ radius: CGFloat, _ degrees: CGFloat) -> CGPoint {
        let radians = degrees * .pi / 180
        return CGPoint(x: centre.x + radius * cos(radians), y: centre.y + radius * sin(radians))
    }

    /// Presses the screen point `start` and drags to the screen point `end` (DesignSnapJourneyTests).
    @MainActor private func drag(_ design: Journey, from start: CGPoint, to end: CGPoint) {
        let window = design.app.windows.firstMatch
        window.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: start.x - window.frame.minX, dy: start.y - window.frame.minY))
            .press(forDuration: 0.1, thenDragTo: window.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: end.x - window.frame.minX, dy: end.y - window.frame.minY)))
    }

    /// ⇧⌘E, SVG, Export, then Done once the sheet reads that one file went out.
    @MainActor private func exportSVG(_ design: Journey) {
        let sheet = design.element("design.export.sheet")
        design.press(character: "e", [.command, .shift])
        XCTAssert(sheet.waitForExistence(timeout: 5), "⇧⌘E opened no export sheet")
        design.element("design.export.format.svg").click()
        design.element("design.export.start").click()
        let done = NSPredicate(format: "label CONTAINS %@ OR value CONTAINS %@", "Exported 1 file to", "Exported 1 file to")
        XCTAssert(Self.waitUntil(timeout: 10) { sheet.descendants(matching: .any).matching(done).firstMatch.exists },
                  "the SVG run never read Exported 1 file to")
        design.element("design.export.dismiss").click()
        XCTAssert(sheet.waitForNonExistence(timeout: 5), "Done left the export sheet open")
    }

    /// The inspector's control with the id `identifier`.
    @MainActor private func control(_ design: Journey, _ identifier: String) -> XCUIElement {
        design.element("suite.inspector").descendants(matching: .any)[identifier].firstMatch
    }

    /// The typing field a clicked bar opens: inside the bar, else the inspector's only one.
    @MainActor private func typingField(_ design: Journey, in bar: XCUIElement) -> XCUIElement {
        let inside = bar.textFields.firstMatch
        if inside.waitForExistence(timeout: 2) { return inside }
        return design.element("suite.inspector").textFields.firstMatch
    }

    /// The first number an element reads ("15", "15°", "15 degrees"), or nil.
    @MainActor private static func number(_ element: XCUIElement) -> Double? {
        if let number = element.value as? NSNumber { return number.doubleValue }
        guard let word = text(element).split(separator: " ").first else { return nil }
        return Double(word.filter { character in character.isNumber || character == "." || character == "-" })
    }

    /// What an element reads: a bar's number (macOS gives a slider's value as a number), else its value or label.
    @MainActor private static func text(_ element: XCUIElement) -> String {
        if let number = element.value as? NSNumber { return number.stringValue }
        let value = element.value as? String ?? ""
        return value.isEmpty ? element.label : value
    }

    /// Whether `element`'s label reads `label` within `timeout` seconds.
    @MainActor private static func waitForLabel(_ element: XCUIElement, _ label: String, timeout: Double = 5) -> Bool {
        waitUntil(timeout: timeout) { element.exists && element.label == label }
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
