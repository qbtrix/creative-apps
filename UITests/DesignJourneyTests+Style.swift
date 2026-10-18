// DesignJourneyTests+Style.swift: J10, the inspector's style rows on one layer
// (packet docs/blueprints/design/features/style-rows.md, Journey steps item 1,
// SR-a, ST-6). On `cards` at 1024 × 768, live services: open Desktop's row
// in Layers (a file opens with its rows collapsed) and click A's row; click
// the Corners Radius bar, type 12, Return: it reads 12 and the top bar's Undo
// reads "Undo Change Corner Radius"; drag the Opacity bar to 50%: "Undo
// Change Opacity"; click Add Stroke: the Width bar reads 1
// (DesignStroke.default); give the Width bar the keys and press → three
// times: it reads 4, and the three presses are one "Undo Change Stroke" step,
// so one Undo puts the width back to 1 (three steps would leave 3); click
// Hidden's row in Layers: Opacity, Radius and Add Stroke are disabled and the
// hint reads "Show Hidden to change it." The bars are ScrubFields: XCUI finds
// each as a slider by its `design.inspector.<name>` id (DesignControlID), its
// value spoken with the unit ("12 points", "50 percent"); a click without a
// drag opens its typing field, and Escape closes it and gives the bar the keys.
import XCTest

final class DesignStyleJourneyTests: XCTestCase {
    static let arguments = ["-DesignFixture", "cards", "-SuiteWindowSize", "1024x768"]
    /// A's and Hidden's rows in Layers (DesignFixtures.cards).
    static let rowA = "design.layer.node-2", hiddenRow = "design.layer.node-10"
    /// Desktop's row, the frame around A and Hidden; collapsed when the file opens.
    static let desktopRow = "design.layer.node-1"
    /// The style rows of DesignInspectorStyle, by their DesignControlID.
    static let radius = "design.inspector.corner-radius", opacity = "design.inspector.opacity"
    static let strokeWidth = "design.inspector.stroke-width", addStroke = "design.inspector.stroke-add"
    static let hiddenHint = "Show Hidden to change it."

    /// J10: radius typed, opacity dragged, a stroke stepped by keys as one step, and Hidden refused.
    @MainActor func testInspectorStyleRows() {
        let design = Journey("Design", self, arguments: Self.arguments)
        XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(design.element("suite.canvas").waitForExistence(timeout: 10), "the cards fixture showed no page (suite.canvas)")
        let undo = design.element("design.bar.undo")

        // 1. A's row in Layers, inside Desktop's, then Radius 12 typed with Return: one Change Corner Radius step.
        design.expandDesignLayer(Self.desktopRow)
        design.clickDesignLayer(Self.rowA)
        let radius = control(design, Self.radius)
        XCTAssert(radius.waitForExistence(timeout: 5), "no Radius bar in the inspector (\(Self.radius))")
        radius.click()
        let field = typingField(design, in: radius)
        XCTAssert(field.waitForExistence(timeout: 5), "clicking Radius opened no typing field")
        design.press(character: "a", .command)
        field.typeText("12")
        design.press(.return)
        XCTAssert(Self.waitUntil { Self.number(radius) == 12 }, "Radius reads \(Self.text(radius)), not 12")
        XCTAssert(Self.waitForLabel(undo, "Undo Change Corner Radius"), "Radius made no step (Undo reads \(undo.label))")
        design.shot("style-radius-12")

        // 2. The Opacity bar dragged to 50%: one Change Opacity step.
        let opacity = control(design, Self.opacity)
        XCTAssert(opacity.waitForExistence(timeout: 5), "no Opacity bar in the inspector (\(Self.opacity))")
        opacity.adjust(toNormalizedSliderPosition: 0.5)
        XCTAssert(Self.waitUntil { Self.number(opacity) == 50 }, "Opacity reads \(Self.text(opacity)), not 50%")
        XCTAssert(Self.waitForLabel(undo, "Undo Change Opacity"), "Opacity made no step (Undo reads \(undo.label))")
        design.shot("style-opacity-50")

        // 3. Add Stroke: the Width bar appears at DesignStroke.default's width, 1.
        let add = control(design, Self.addStroke)
        XCTAssert(add.waitForExistence(timeout: 5), "no Add Stroke in the inspector (\(Self.addStroke))")
        add.click()
        let width = control(design, Self.strokeWidth)
        XCTAssert(width.waitForExistence(timeout: 5), "Add Stroke showed no Width bar (\(Self.strokeWidth))")
        XCTAssert(Self.waitUntil { Self.number(width) == 1 }, "a new stroke's Width reads \(Self.text(width)), not 1")
        XCTAssert(Self.waitForLabel(undo, "Undo Change Stroke"), "Add Stroke made no step (Undo reads \(undo.label))")

        // 4. The Width bar takes the keys (a click opens typing; Escape closes it), then → three times: 4.
        width.click()
        design.press(.escape)
        for _ in 0..<3 { design.press(.rightArrow) }
        XCTAssert(Self.waitUntil { Self.number(width) == 4 }, "→ three times left Width at \(Self.text(width)), not 4")
        XCTAssertEqual(undo.label, "Undo Change Stroke", "the → run made no Change Stroke step")
        design.shot("style-stroke-width-4")

        // 5. One Undo takes back the whole → run: Width reads 1, the Add Stroke step's width.
        undo.click()
        XCTAssert(Self.waitUntil { Self.number(width) == 1 }, "one Undo left Width at \(Self.text(width)): the → run was several steps")
        XCTAssertEqual(undo.label, "Undo Change Stroke", "Undo took back Add Stroke with the → run")
        design.shot("style-stroke-run-undone")

        // 6. Hidden's row in Layers: its style rows are disabled, saying why.
        design.clickDesignLayer(Self.hiddenRow)
        let rows = [control(design, Self.opacity), control(design, Self.radius), control(design, Self.addStroke)]
        XCTAssert(Self.waitUntil { rows.allSatisfy { $0.exists && !$0.isEnabled } },
                  "a style row is enabled on Hidden (\(rows.map { "\($0.identifier): \($0.isEnabled)" }))")
        let reason = design.element("suite.inspector").descendants(matching: .any).matching(
            NSPredicate(format: "label == %@ OR value == %@", Self.hiddenHint, Self.hiddenHint)).firstMatch
        XCTAssert(reason.waitForExistence(timeout: 5), "the disabled style rows don't say \"\(Self.hiddenHint)\"")
        design.shot("style-hidden-refused")
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

    /// The first number an element reads ("12 points", "50 percent", "4"), or nil.
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
