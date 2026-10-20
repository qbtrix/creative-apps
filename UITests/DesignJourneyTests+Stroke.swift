// DesignJourneyTests+Stroke.swift: stroke-style J-DK, a dashed border
// (packet docs/blueprints/design/features/stroke-style.md, Journey steps). On
// `-DesignFixture cards` every step uses the mouse or the keys on visible
// controls: A's row in Layers, the inspector's Stroke editor and the top bar's
// Undo. A starts with no stroke. Add Stroke gives a 1 pt black stroke and the
// editor shows Width, Join, Cap and Dash; Width 2, Round cap and Dashed are one
// step each, and three Undos give a plain 1 pt stroke back. Step 4 opens
// `old-strokes.design`, which DK-8 adds with the live services.
// Written before its code (lead.md, contract rule 13): DK-2 writes it skipped;
// the pickers stay off until DK-6 builds `setStroke`, Dash until the core
// bump, so DK-8 turns it on.
import XCTest

final class DesignStrokeJourneyTests: XCTestCase {
    static let arguments = ["-DesignFixture", "cards", "-SuiteWindowSize", "1024x768"]
    static let rowA = "design.layer.node-2", desktopRow = "design.layer.node-1"
    static let add = "design.inspector.stroke-add", width = "design.inspector.stroke-width"
    static let join = "design.inspector.stroke-join", cap = "design.inspector.stroke-cap"
    static let dash = "design.inspector.stroke-dash"

    /// J-DK: Add Stroke, Width 2, Round cap and Dashed, each one step; three Undos take them back.
    @MainActor func testDashedBorder() throws {
        throw XCTSkip("waits on DK-8")
        walkDashedBorder()
    }

    /// The journey itself, steps 1 to 3.
    @MainActor private func walkDashedBorder() {
        let design = Journey("Design", self, arguments: Self.arguments)
        XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(design.element("suite.canvas").waitForExistence(timeout: 10), "cards showed no page (suite.canvas)")
        let undo = design.element("design.bar.undo")

        // 1. A, which has no stroke, then Add Stroke: a 1 pt stroke, and the editor shows Width, Join, Cap and Dash.
        design.expandDesignLayer(Self.desktopRow)
        design.clickDesignLayer(Self.rowA)
        let add = control(design, Self.add)
        XCTAssert(add.waitForExistence(timeout: 5), "no Add Stroke in the inspector (\(Self.add))")
        add.click()
        let width = control(design, Self.width)
        XCTAssert(width.waitForExistence(timeout: 5), "Add Stroke showed no Width bar (\(Self.width))")
        for id in [Self.join, Self.cap, Self.dash] {
            XCTAssert(control(design, id).waitForExistence(timeout: 5), "the Stroke editor shows no \(id)")
        }
        XCTAssert(Self.waitUntil { Self.number(width) == 1 }, "a new stroke's Width reads \(width.value ?? "nothing"), not 1")
        design.shot("stroke-added")

        // 2. Width scrubbed to 2 (one → after the click and Escape), Round cap, Dashed: one step each.
        width.click()
        design.press(.escape)
        design.press(.rightArrow)
        XCTAssert(Self.waitUntil { Self.number(width) == 2 }, "→ left Width at \(width.value ?? "nothing"), not 2")
        pick(design, Self.cap, "Round")
        pick(design, Self.dash, "Dashed")
        XCTAssert(Self.waitUntil { control(design, Self.dash).value as? String == "Dashed" }, "Dash doesn't read Dashed")
        design.shot("stroke-dashed")

        // 3. Three Undos: back to a plain 1 pt stroke.
        for _ in 0..<3 { undo.click() }
        XCTAssert(Self.waitUntil { Self.number(width) == 1 }, "three Undos left Width at \(width.value ?? "nothing"), not 1")
        XCTAssert(Self.waitUntil { control(design, Self.dash).value as? String == "Solid" }, "three Undos kept the dash")
        XCTAssert(Self.waitUntil { control(design, Self.cap).value as? String == "Butt" }, "three Undos kept the round cap")
        design.shot("stroke-undone")
    }

    /// Opens the picker `identifier` and clicks its choice `title`.
    @MainActor private func pick(_ design: Journey, _ identifier: String, _ title: String) {
        let picker = control(design, identifier)
        XCTAssert(picker.waitForExistence(timeout: 5) && picker.isEnabled, "\(identifier) is missing or disabled")
        picker.click()
        let item = design.app.menuItems[title].firstMatch
        XCTAssert(item.waitForExistence(timeout: 5), "\(identifier) offers no \(title)")
        item.click()
        XCTAssert(Self.waitUntil { picker.value as? String == title }, "\(identifier) reads \(picker.value ?? "nothing"), not \(title)")
    }

    /// The inspector's control with the id `identifier`.
    @MainActor private func control(_ design: Journey, _ identifier: String) -> XCUIElement {
        design.element("suite.inspector").descendants(matching: .any)[identifier].firstMatch
    }

    /// The first number an element reads ("2 points", "2"), or nil.
    @MainActor private static func number(_ element: XCUIElement) -> Double? {
        if let number = element.value as? NSNumber { return number.doubleValue }
        guard let word = (element.value as? String ?? "").split(separator: " ").first else { return nil }
        return Double(word.filter { $0.isNumber || $0 == "." || $0 == "-" })
    }

    /// Whether `condition` holds within five seconds.
    @MainActor private static func waitUntil(_ condition: () -> Bool) -> Bool {
        for _ in 0..<25 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }
}
