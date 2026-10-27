// DesignJourneyTests+Eyedropper.swift (eyedropper DY-2 written, DY-7 turned on): J-DY, picking a fill and a stroke
// from one layer onto another, as a person does (docs/blueprints/design/features/eyedropper.md, Journey steps). On
// `cards` at 1024 × 768, live services. `cards` has no red or blue layer, so its own colours stand in: A (a light
// grey #D9D9D9 rectangle, 100, 100, 100 × 80) is the rectangle picked onto, Title (black text, 100, 40, 200 × 32)
// the shape whose fill is picked, E1 (a grey ellipse, 900, 400, 100 × 100) the layer whose colour Option-click
// picks onto the stroke, and Desktop's white the square the 5 × 5 chip reads.
// 1. Open Desktop's row, click A's, click the palette's Eyedropper (`design.tool.eyedropper`): it is selected, the
//    status line's tool (`design.status.tool`) reads Eyedropper, and the loupe (`suite.sample.loupe`) follows the
//    pointer, reading Title's #000000 over it. The inspector's Eyedropper section shows the size chips on Point
//    (`suite.sample.size.1`) and the Fill/Stroke picker (`design.sample.target`) (#3985, #3986).
// 2. Click Title: A's fill turns black, one "Fill" step (the top bar's Undo names it); the loupe over A reads
//    #000000.
// 3. Option-click E1: A gains a stroke, one "Stroke" step. Choosing Stroke in the inspector turns a plain click
//    onto the stroke (#3993) and the 5 × 5 chip reads the square the loupe shows (#3991): a click on Desktop's
//    white is a second "Stroke" step, and Undo takes back only that one, leaving the Option-click's.
// 4. Click the palette's Move (`design.tool.move`): it is selected, the status line reads Move, A still selected
//    ("1 Layer").
// 5. Keyboard parity: press I, the Eyedropper is selected; press V, Move is back.
// The Fill/Stroke picker is a system segmented Picker, so a segment's state is read as selected or as its
// value (1 for the picked one), the accessibility value a radio button carries.
// Shots: design-eyedropper-active, -fill, -stroke, -stroke-target, -move.
import XCTest

final class DesignEyedropperJourneyTests: XCTestCase {
    static let arguments = ["-DesignServices", "live", "-DesignFixture", "cards", "-SuiteWindowSize", "1024x768"]
    /// The page's width in `cards` (DesignFixtures.cards), which sets the artboard's scale.
    static let pageWidth = 1440.0
    static let artboard = "suite.canvas.artboard", loupe = "suite.sample.loupe", target = "design.sample.target"
    /// Desktop's and A's rows in Layers (DesignFixtures.cards).
    static let desktopRow = "design.layer.node-1", rowA = "design.layer.node-2"
    /// Page points inside Title, A, E1 and Desktop's empty white.
    static let title = (150.0, 56.0), middleA = (150.0, 140.0), middleE1 = (950.0, 450.0), white = (620.0, 320.0)

    /// J-DY: the Eyedropper picks Title's black onto A's fill, E1 and Desktop onto its stroke, then Move and I/V.
    @MainActor func testPickFillFromShape() throws {
        let design = Journey("Design", self, arguments: Self.arguments)
        XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let artboard = design.element(Self.artboard)
        XCTAssert(artboard.waitForExistence(timeout: 10), "cards showed no page (\(Self.artboard))")
        let undo = design.element("design.bar.undo")

        // 1. A selected, then the palette's Eyedropper: picked, named in the status line, its options and loupe up.
        design.expandDesignLayer(Self.desktopRow)
        design.clickDesignLayer(Self.rowA)
        expectCount(design, "1 Layer", after: "clicking A's row")
        tool(design, "Eyedropper").click()
        expectTool(design, "Eyedropper", after: "the palette's Eyedropper")
        let onePoint = control(design, "suite.sample.size.1")
        XCTAssert(onePoint.waitForExistence(timeout: 5), "the inspector shows no Point chip (suite.sample.size.1)")
        XCTAssert(onePoint.isSelected, "the size chips aren't on Point")
        XCTAssert(control(design, Self.target).waitForExistence(timeout: 5), "no Fill/Stroke picker (\(Self.target))")
        expectLoupe(design, at: Self.title, "#000000", over: "Title")
        design.shot("eyedropper-active")

        // 2. A click on Title: A's fill is Title's black, one Fill step.
        point(Self.title, on: artboard).click()
        XCTAssert(Self.waitForLabel(undo, "Undo Fill"), "the click on Title made no Fill step (Undo reads \(undo.label))")
        expectLoupe(design, at: Self.middleA, "#000000", over: "A after the pick")
        design.shot("eyedropper-fill")

        // 3. Option-click on E1: a Stroke step. Then Stroke and 5 × 5: a plain click on white is a second one.
        let optionClick = point(Self.middleE1, on: artboard)
        XCUIElement.perform(withKeyModifiers: .option) { optionClick.click() }
        XCTAssert(Self.waitForLabel(undo, "Undo Stroke"), "the Option-click on E1 made no Stroke step (Undo reads \(undo.label))")
        design.shot("eyedropper-stroke")
        let stroke = control(design, Self.target).descendants(matching: .any)["Stroke"].firstMatch
        XCTAssert(stroke.waitForExistence(timeout: 5), "the picker has no Stroke choice")
        stroke.click()
        XCTAssert(Self.waitUntil { Self.isPicked(stroke) }, "clicking Stroke didn't pick it")
        let five = control(design, "suite.sample.size.5")
        XCTAssert(five.waitForExistence(timeout: 5), "the inspector shows no 5 × 5 chip (suite.sample.size.5)")
        five.click()
        XCTAssert(Self.waitUntil { five.isSelected }, "clicking 5 × 5 didn't pick it")
        expectLoupe(design, at: Self.white, "#FFFFFF", over: "Desktop's white")
        point(Self.white, on: artboard).click()
        XCTAssert(Self.waitForLabel(undo, "Undo Stroke"), "the plain click with Stroke chosen made no Stroke step")
        design.shot("eyedropper-stroke-target")
        undo.click()
        let redo = design.element("design.bar.redo")
        XCTAssert(Self.waitForLabel(redo, "Redo Stroke"), "Undo didn't take back the white stroke (Redo reads \(redo.label))")
        XCTAssert(Self.waitForLabel(undo, "Undo Stroke"), "one Undo took the Option-click's stroke too (Undo reads \(undo.label))")

        // 4. The palette's Move: picked, named in the status line, A still selected.
        tool(design, "Move").click()
        expectTool(design, "Move", after: "the palette's Move")
        expectCount(design, "1 Layer", after: "leaving the Eyedropper")
        design.shot("eyedropper-move")

        // 5. Keyboard parity: I picks the Eyedropper, V brings Move back.
        design.press(character: "i")
        expectTool(design, "Eyedropper", after: "pressing I")
        design.press(character: "v")
        expectTool(design, "Move", after: "pressing V")
    }

    // MARK: - Steps

    /// The tool box's button `title`.
    @MainActor private func tool(_ design: Journey, _ title: String) -> XCUIElement {
        let button = design.element("suite.tools").buttons[title]
        XCTAssert(button.waitForExistence(timeout: 5), "no \(title) in the tool box (suite.tools)")
        XCTAssert(button.isEnabled, "the palette's \(title) is disabled")
        return button
    }

    /// The palette shows `title` picked and the status line names it, within five seconds of `action`.
    @MainActor private func expectTool(_ design: Journey, _ title: String, after action: String) {
        let button = design.element("suite.tools").buttons[title]
        let status = design.element("design.status.tool")
        XCTAssert(status.waitForExistence(timeout: 5), "no tool in the status line (design.status.tool)")
        XCTAssert(Self.waitUntil { button.isSelected }, "the palette doesn't show \(title) picked after \(action)")
        XCTAssert(Self.waitUntil { Self.text(status) == title },
                  "the status line reads \(Self.text(status)), not \(title), after \(action)")
    }

    /// The pointer rests on the page point `page`: the loupe shows there and reads `hex`.
    @MainActor private func expectLoupe(_ design: Journey, at page: (Double, Double), _ hex: String, over what: String) {
        point(page, on: design.element(Self.artboard)).hover()
        let loupe = design.element(Self.loupe)
        XCTAssert(loupe.waitForExistence(timeout: 5), "no loupe over \(what) (\(Self.loupe))")
        XCTAssert(Self.waitUntil { loupe.label == hex }, "the loupe over \(what) reads \(loupe.label), not \(hex)")
    }

    /// The status bar's selection count reads `expected`.
    @MainActor private func expectCount(_ design: Journey, _ expected: String, after step: String) {
        let count = design.element("design.status.selection")
        XCTAssert(Self.waitUntil { count.exists && Self.text(count) == expected },
                  "after \(step) the selection reads \(count.exists ? Self.text(count) : "nothing"), not \(expected)")
    }

    /// The inspector's control with the id `identifier`.
    @MainActor private func control(_ design: Journey, _ identifier: String) -> XCUIElement {
        design.element("suite.inspector").descendants(matching: .any)[identifier].firstMatch
    }

    /// The screen point of the page point: the artboard's corner plus the point at its scale.
    @MainActor private func point(_ page: (Double, Double), on artboard: XCUIElement) -> XCUICoordinate {
        let scale = artboard.frame.width / Self.pageWidth
        return artboard.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: page.0 * scale, dy: page.1 * scale))
    }

    /// What an element reads: its value where macOS puts it, else its label.
    @MainActor private static func text(_ element: XCUIElement) -> String {
        let value = element.value as? String ?? ""
        return value.isEmpty ? element.label : value
    }

    /// Whether a system segmented picker's segment is the picked one: selected, or valued 1.
    @MainActor private static func isPicked(_ segment: XCUIElement) -> Bool {
        segment.isSelected || (segment.value as? NSNumber)?.intValue == 1
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
