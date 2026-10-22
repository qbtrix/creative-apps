// DesignJourneyTests+Gradient.swift (gradient-fill DG-3 written, DG-7 turned on): DJ-G1, giving shapes and text a
// gradient, as a person does (docs/blueprints/design/features/gradient-fill.md, Journey steps). On `cards` at
// 1024 × 768, live services, exporting into `-DesignExportTo <tmp folder>` (no folder panel). A, a rectangle in the
// Desktop frame, stands in for the background rectangle; Title is the text layer.
// 1. Open Desktop's row in Layers, click A's, pick Linear in the Fill section (`design.inspector.fill-type.linear`):
//    one "Fill Type" step, the stop bar (`suite.gradient.bar`) holds A's grey and white, and the canvas changes.
// 2. Click the angle bar (`suite.gradient.angle`, a ScrubField), type 90, Return: it reads 90, one "Gradient Angle"
//    step, and the canvas changes.
// 3. Click the stop bar's middle: a third stop ("Add Gradient Stop"); click it and type D62828 in the editor's hex
//    field (`suite.gradient.color`): it reads red ("Gradient Stop Color"). The top bar's Undo takes the colour back,
//    and Undo again the stop (one step each), leaving the angle.
// 4. Click Title's row, pick Radial (`design.inspector.fill-type.radial`): one "Fill Type" step, no angle row, and
//    the letters change on the canvas.
// 5. Click Desktop's row, ⇧⌘E, SVG, Export: Desktop.svg's `linearGradient` for A runs top to bottom in frame space
//    (x1 = x2 = 150, y1 100, y2 180) and Title fills with a `radialGradient`.
// Shots: design-gradient-linear, -angle-90, -stop-added, -stop-colored, -stop-undone, -radial-text, -exported.
import XCTest

final class DesignGradientJourneyTests: XCTestCase {
    static let arguments = ["-DesignServices", "live", "-DesignFixture", "cards", "-SuiteWindowSize", "1024x768"]
    /// Desktop's, A's and Title's rows in Layers (DesignFixtures.cards); Desktop opens collapsed.
    static let desktopRow = "design.layer.node-1", rowA = "design.layer.node-2", titleRow = "design.layer.node-5"
    /// The Fill section's type chips (DesignInspectorFill: `DesignControlID.inspectorFillType`.<type>).
    static let linear = "design.inspector.fill-type.linear", radial = "design.inspector.fill-type.radial"
    /// SuiteUI's GradientEditor rows.
    static let bar = "suite.gradient.bar", angle = "suite.gradient.angle", color = "suite.gradient.color"
    /// The third stop's colour, which GradientEditorText names "red".
    static let red = "D62828"
    /// A (100, 100, 100 × 80 in Desktop at the origin) at 90°: the line down its middle, top to bottom.
    static let downA = #"x1="150" y1="100" x2="150" y2="180""#

    /// DJ-G1: Linear on A, 90°, a third stop coloured and undone, Radial on Title, then the SVG.
    @MainActor func testGradientFillAngle() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("design-gradient-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let design = Journey("Design", self, arguments: Self.arguments + ["-DesignExportTo", folder.path])
        XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(design.element("suite.canvas").waitForExistence(timeout: 10), "the cards fixture showed no page (suite.canvas)")
        let undo = design.element("design.bar.undo")

        // 1. A, then Linear: one Fill Type step; the bar holds A's colour fading to white.
        design.expandDesignLayer(Self.desktopRow)
        design.clickDesignLayer(Self.rowA)
        let solid = canvasPixels(design)
        click(design, Self.linear)
        XCTAssert(Self.waitForLabel(undo, "Undo Fill Type"), "Linear made no Fill Type step (Undo reads \(undo.label))")
        let stopBar = control(design, Self.bar)
        XCTAssert(stopBar.waitForExistence(timeout: 5), "Linear showed no stop bar (\(Self.bar))")
        XCTAssert(control(design, "suite.gradient.stop.1").label.hasSuffix("white"), "Linear's last stop isn't white")
        XCTAssert(canvasChanged(from: solid, design), "Linear left A's solid fill on the canvas")
        design.shot("gradient-linear")

        // 2. The angle bar typed to 90: the fade runs top to bottom.
        let angle = control(design, Self.angle)
        XCTAssert(angle.waitForExistence(timeout: 5), "a linear fill shows no angle bar (\(Self.angle))")
        design.reveal(angle)
        let across = canvasPixels(design)
        angle.click()
        let field = typingField(design, in: angle)
        XCTAssert(field.waitForExistence(timeout: 5), "clicking Angle opened no typing field")
        design.press(character: "a", .command)
        field.typeText("90")
        design.press(.return)
        XCTAssert(Self.waitUntil { Self.number(angle) == 90 }, "Angle reads \(Self.text(angle)), not 90")
        XCTAssert(Self.waitForLabel(undo, "Undo Gradient Angle"), "Angle made no step (Undo reads \(undo.label))")
        XCTAssert(canvasChanged(from: across, design), "90° left the fade running left to right")
        design.shot("gradient-angle-90")

        // 3. A click on the bar's middle adds a stop; the hex field colours it red; Undo, Undo: colour, then stop.
        design.reveal(stopBar)
        stopBar.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3)).click()
        XCTAssert(Self.waitForLabel(undo, "Undo Add Gradient Stop"), "the bar's click added no stop (Undo reads \(undo.label))")
        let third = control(design, "suite.gradient.stop.2")
        XCTAssert(third.waitForExistence(timeout: 5), "the bar's click left two stops")
        design.shot("gradient-stop-added")
        setStop(1, to: Self.red, design)
        XCTAssert(Self.waitForLabel(undo, "Undo Gradient Stop Color"), "the hex field made no colour step (Undo reads \(undo.label))")
        let middle = control(design, "suite.gradient.stop.1")
        XCTAssert(Self.waitUntil { middle.label.hasSuffix("red") }, "the middle stop reads \(middle.label), not red")
        design.shot("gradient-stop-colored")
        undo.click()
        XCTAssert(Self.waitForLabel(undo, "Undo Add Gradient Stop"), "one Undo took more than the colour (Undo reads \(undo.label))")
        XCTAssert(Self.waitUntil { !middle.label.hasSuffix("red") }, "Undo left the middle stop red")
        XCTAssert(third.exists, "one Undo took the stop with its colour")
        undo.click()
        XCTAssert(Self.waitForLabel(undo, "Undo Gradient Angle"), "the second Undo didn't stop at the angle (Undo reads \(undo.label))")
        XCTAssert(third.waitForNonExistence(timeout: 5), "the second Undo left three stops")
        XCTAssert(Self.waitUntil { Self.number(angle) == 90 }, "the Undos took the angle too (Angle reads \(Self.text(angle)))")
        design.shot("gradient-stop-undone")

        // 4. Title, then Radial: its letters take the gradient; a radial fill has no angle row.
        design.clickDesignLayer(Self.titleRow)
        let black = canvasPixels(design)
        click(design, Self.radial)
        XCTAssert(Self.waitForLabel(undo, "Undo Fill Type"), "Radial made no Fill Type step (Undo reads \(undo.label))")
        XCTAssert(control(design, Self.bar).waitForExistence(timeout: 5), "Radial showed no stop bar")
        XCTAssertFalse(control(design, Self.angle).exists, "a radial fill shows an angle row")
        XCTAssert(canvasChanged(from: black, design), "Radial left Title's letters solid")
        design.shot("gradient-radial-text")

        // 5. Desktop as SVG: A's linear gradient runs top to bottom in frame space; Title's is radial.
        design.clickDesignLayer(Self.desktopRow)
        exportSVG(design)
        let svg = try String(contentsOf: folder.appendingPathComponent("Desktop.svg"), encoding: .utf8)
        XCTAssert(svg.contains(#"<linearGradient id="g-node-2" gradientUnits="userSpaceOnUse" "# + Self.downA),
                  "Desktop.svg's gradient for A doesn't run top to bottom (\(Self.downA))")
        XCTAssert(svg.contains(#"fill="url(#g-node-2)""#), "A doesn't fill with its gradient in Desktop.svg")
        XCTAssert(svg.contains(#"<radialGradient id="g-node-5""#), "Desktop.svg holds no radialGradient for Title")
        XCTAssert(svg.contains(#"fill="url(#g-node-5)""#), "Title's letters don't fill with its gradient in Desktop.svg")
        design.shot("gradient-exported")
    }

    // MARK: - Steps

    /// Reveals the inspector's control `identifier` and clicks it.
    @MainActor private func click(_ design: Journey, _ identifier: String) {
        let element = control(design, identifier)
        XCTAssert(element.waitForExistence(timeout: 5), "no \(identifier) in the inspector")
        design.reveal(element)
        XCTAssert(element.isEnabled, "\(identifier) is disabled")
        element.click()
    }

    /// Picks stop `index` on the bar and types `hex` into the editor's colour field (PhotoGradientJourneyTests).
    @MainActor private func setStop(_ index: Int, to hex: String, _ design: Journey) {
        let stop = control(design, "suite.gradient.stop.\(index)")
        XCTAssert(stop.waitForExistence(timeout: 5), "no stop handle suite.gradient.stop.\(index)")
        stop.click()
        let field = design.element("suite.inspector").textFields.matching(NSPredicate(
            format: "identifier == %@ OR label == %@", Self.color, "Color Hex")).firstMatch
        XCTAssert(field.waitForExistence(timeout: 5), "no gradient Color Hex field (\(Self.color))")
        design.reveal(field)
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()
        design.press(.rightArrow, .command)
        design.press(.leftArrow, [.command, .shift])
        design.app.typeText(hex)
        design.press(.return)
    }

    /// ⇧⌘E, the SVG chip, Export: the run finishes, then Done (DesignExportJourneyTests.exportAgain).
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

    @MainActor private func canvasPixels(_ design: Journey) -> Data {
        design.element("suite.canvas").screenshot().pngRepresentation
    }

    /// Whether the canvas stops matching `before` within five seconds.
    @MainActor private func canvasChanged(from before: Data, _ design: Journey) -> Bool {
        Self.waitUntil { self.canvasPixels(design) != before }
    }

    /// The first number an element reads ("90", "90°", "90 degrees"), or nil.
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
