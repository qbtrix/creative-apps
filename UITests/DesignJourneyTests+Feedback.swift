// DesignJourneyTests+Feedback.swift: the canvas shows what a click will do
// (packet docs/blueprints/design/features/design-window.md, Journey steps
// item 6, D0-9a). On `-DesignFixture cards` at 1024 × 768, with live services,
// every step uses the mouse on visible controls, never a shortcut (lesson 152).
// The canvas publishes what the pointer would show as the hover mark's
// accessibility value (`design.canvas.hover`: "move", "resize-bottom-right",
// "copy", "text"), and the size badge reads `design.canvas.badge`.
// The page of `cards` is 1440 × 1024 points, and the canvas's fractions map to
// the page as TextBox's journey does (dx 0.05, dy 0.85 is (72, 870) on the page).
// The one zoom-dependent check reads its scale from A's selection frame, so it
// holds at any zoom. Holding Option while hovering has no XCUI API, so that
// step posts CGEvents, as FlareJourneyTests+Draw does for its drags.
// Written before its code (lead.md, contract rule 13): D0-9a writes the walk
// skipped by name, and D0-9d deletes the skip line once the hover, badge and
// text-preview views exist.
import XCTest

final class DesignFeedbackJourneyTests: XCTestCase {
    static let arguments = ["-DesignFixture", "cards", "-SuiteWindowSize", "1024x768"]
    /// The page of `cards` is 1440 × 1024 points.
    static let pageWidth = 1440.0, pageHeight = 1024.0
    /// The Option key's virtual key code (kVK_Option).
    static let optionKeyCode: CGKeyCode = 58

    /// The five feedback steps: the hover outline, the move and resize pointers,
    /// the copy pointer, the size badge, and the Text tool's preview and click-drag.
    @MainActor func testCanvasFeedback() throws {
        throw XCTSkip("waits on D0-9d")
        walkCanvasFeedback()
    }

    /// The journey itself, which D0-9d runs once it drops the skip above.
    @MainActor private func walkCanvasFeedback() {
        let design = Journey("Design", self, arguments: Self.arguments)
        XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        let canvas = design.element("suite.canvas")
        XCTAssert(canvas.waitForExistence(timeout: 10), "the cards fixture showed no page (suite.canvas)")
        let tools = design.element("suite.tools").buttons
        let hover = design.element("design.canvas.hover")
        let badge = design.element("design.canvas.badge")

        // 1. Hover outline: Move in the tool box, then the pointer over A.
        XCTAssert(tools["Move"].waitForExistence(timeout: 5), "no Move in the tool box (suite.tools)")
        tools["Move"].click()
        let aCenter = Self.frac(150, 140), aCorner = Self.frac(200, 180)
        canvas.coordinate(withNormalizedOffset: aCenter).hover()
        XCTAssert(hover.waitForExistence(timeout: 5), "hovering A shows no hover mark (design.canvas.hover)")
        // A is selected by a click on it; the selection mark is A's frame on screen, which the hover mark must match.
        canvas.coordinate(withNormalizedOffset: aCenter).click()
        let selection = design.element("design.canvas.selection")
        XCTAssert(selection.waitForExistence(timeout: 5), "A's selection shows no mark (design.canvas.selection)")
        canvas.coordinate(withNormalizedOffset: aCenter).hover()
        Self.expectFrame(hover.frame, matches: selection.frame, "the hover mark over A")
        let scale = selection.frame.width / 100
        design.shot("feedback-hover-a")

        // Hovering Desktop's blank area outlines Desktop, which is ten times A's width or more.
        canvas.coordinate(withNormalizedOffset: Self.frac(950, 735)).hover()
        XCTAssert(Self.waitForFrame(hover) { $0.width >= 10 * selection.frame.width },
                  "the hover mark over Desktop's blank area isn't Desktop's outline")
        design.shot("feedback-hover-desktop")

        // The canvas surround, past the page's edge, has no hover mark.
        canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.01, dy: 0.99)).hover()
        XCTAssert(Self.waitForGone(hover), "the hover mark stays on the canvas surround")
        design.shot("feedback-hover-gone")

        // 2. Move and resize pointers: inside A, then its bottom-right handle.
        canvas.coordinate(withNormalizedOffset: aCenter).click()
        canvas.coordinate(withNormalizedOffset: aCenter).hover()
        XCTAssert(Self.waitForValue(hover, "move"), "A's pointer isn't move (design.canvas.hover reads \(Self.value(hover)))")
        design.shot("feedback-pointer-move")
        canvas.coordinate(withNormalizedOffset: aCorner).hover()
        XCTAssert(Self.waitForValue(hover, "resize-bottom-right"),
                  "A's handle pointer isn't resize-bottom-right (design.canvas.hover reads \(Self.value(hover)))")
        design.shot("feedback-pointer-resize")

        // 3. Copy pointer: with A selected, hold Option and hover A.
        canvas.coordinate(withNormalizedOffset: aCenter).hover()
        Self.postKey(Self.optionKeyCode, down: true)
        Self.moveMouse(to: canvas.coordinate(withNormalizedOffset: aCenter).withOffset(CGVector(dx: 2, dy: 0)).screenPoint, flags: .maskAlternate)
        XCTAssert(Self.waitForValue(hover, "copy"), "holding Option over A isn't copy (design.canvas.hover reads \(Self.value(hover)))")
        design.shot("feedback-pointer-copy")
        Self.postKey(Self.optionKeyCode, down: false)

        // 4. Size badge: A's size, then after dragging its handle by (20, 10), then a new 120 × 80 box.
        XCTAssert(Self.waitForText(badge, "100 × 80"), "the badge doesn't read A's size 100 × 80 (design.canvas.badge reads \(Self.text(badge)))")
        design.shot("feedback-badge-a")
        design.drag(on: "suite.canvas", from: Self.frac(200, 180), to: Self.frac(220, 190))
        XCTAssert(Self.waitForText(badge, "120 × 90"), "the badge doesn't read 120 × 90 after the resize (reads \(Self.text(badge)))")
        design.shot("feedback-badge-resized")
        tools["Rectangle"].click()
        design.drag(on: "suite.canvas", from: Self.frac(800, 620), to: Self.frac(920, 700), step: "feedback-badge-drawn")
        XCTAssert(Self.waitForText(badge, "120 × 80"), "the badge doesn't read 120 × 80 for the new box (reads \(Self.text(badge)))")

        // 5. Text preview: the Text tool's 120 × 24 box at the pointer, then a 300 pt click-drag.
        XCTAssert(tools["Text"].waitForExistence(timeout: 5), "no Text in the tool box (suite.tools)")
        tools["Text"].click()
        let textPoint = canvas.coordinate(withNormalizedOffset: Self.frac(72, 870))
        textPoint.hover()
        XCTAssert(Self.waitForValue(hover, "text"), "the Text tool's pointer isn't text (design.canvas.hover reads \(Self.value(hover)))")
        Self.expectSize(hover.frame, width: 120 * scale, height: 24 * scale, "the Text tool's hover mark")
        XCTAssert(hover.frame.insetBy(dx: -1, dy: -1).contains(textPoint.screenPoint),
                  "the Text tool's box isn't at the pointer")
        design.shot("feedback-text-hover")

        design.drag(on: "suite.canvas", from: Self.frac(72, 870), to: Self.frac(372, 900))
        let editor = design.element("design.text")
        XCTAssert(editor.waitForExistence(timeout: 5), "the click-drag opened no text editor (design.text)")
        Self.expectSize(editor.frame, width: 300 * scale, height: nil, "the text editor")
        design.shot("feedback-text-box")
        design.app.typeText("Hello")
        design.press(.return, step: "feedback-text-typed")
        XCTAssert(Self.waitForInspector(design, "Width", 300), "the inspector's W doesn't read 300 after Return")
        design.shot("feedback-text-committed")
    }

    /// A page point (x, y) as a canvas fraction, the way the other Design journeys map the page.
    private static func frac(_ x: Double, _ y: Double) -> CGVector {
        CGVector(dx: x / pageWidth, dy: y / pageHeight)
    }

    /// The accessibility value of `element`, or "" when it has none.
    @MainActor private static func value(_ element: XCUIElement) -> String {
        element.value as? String ?? ""
    }

    /// A Text's words, read as its label, or its value on macOS.
    @MainActor private static func text(_ element: XCUIElement) -> String {
        element.label.isEmpty ? value(element) : element.label
    }

    /// Whether `element`'s accessibility value reads `expected` within five seconds.
    @MainActor private static func waitForValue(_ element: XCUIElement, _ expected: String) -> Bool {
        poll { element.exists && value(element) == expected }
    }

    /// Whether `element`'s words read `expected` within five seconds.
    @MainActor private static func waitForText(_ element: XCUIElement, _ expected: String) -> Bool {
        poll { element.exists && text(element) == expected }
    }

    /// Whether `element`'s frame passes `condition` within five seconds.
    @MainActor private static func waitForFrame(_ element: XCUIElement, _ condition: (CGRect) -> Bool) -> Bool {
        poll { element.exists && condition(element.frame) }
    }

    /// Whether `element` is gone within five seconds.
    @MainActor private static func waitForGone(_ element: XCUIElement) -> Bool {
        poll { !element.exists }
    }

    /// Whether the inspector's field `name` reads `expected` (its spoken value, "300 points") within five seconds.
    @MainActor private static func waitForInspector(_ design: Journey, _ name: String, _ expected: Double) -> Bool {
        poll {
            let field = design.element("suite.inspector").descendants(matching: .any)
                .matching(NSPredicate(format: "label == %@", name)).firstMatch
            guard field.exists, let spoken = field.value as? String, let word = spoken.split(separator: " ").first else { return false }
            return Double(word.filter { $0.isNumber || $0 == "." || $0 == "-" }) == expected
        }
    }

    /// Polls `condition` for up to five seconds, with the run loop turning meanwhile.
    @MainActor private static func poll(_ condition: () -> Bool) -> Bool {
        for _ in 0..<25 {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.2)
        }
        return condition()
    }

    /// Each edge of `actual` is within a point of `expected`'s.
    @MainActor private static func expectFrame(_ actual: CGRect, matches expected: CGRect, _ what: String) {
        XCTAssertEqual(actual.minX, expected.minX, accuracy: 1, "\(what) starts at the wrong x")
        XCTAssertEqual(actual.minY, expected.minY, accuracy: 1, "\(what) starts at the wrong y")
        XCTAssertEqual(actual.width, expected.width, accuracy: 1, "\(what) is the wrong width")
        XCTAssertEqual(actual.height, expected.height, accuracy: 1, "\(what) is the wrong height")
    }

    /// The width, and the height when given, are within a point of the expected size.
    @MainActor private static func expectSize(_ frame: CGRect, width: Double, height: Double?, _ what: String) {
        XCTAssertEqual(frame.width, width, accuracy: 1, "\(what) is \(frame.width) wide, not \(width)")
        if let height {
            XCTAssertEqual(frame.height, height, accuracy: 1, "\(what) is \(frame.height) tall, not \(height)")
        }
    }

    /// Presses or releases `key` as a CGEvent, to hold a modifier while the pointer moves.
    @MainActor private static func postKey(_ key: CGKeyCode, down: Bool) {
        CGEvent(keyboardEventSource: nil, virtualKey: key, keyDown: down)?.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.2)
    }

    /// Moves the pointer to `point` on screen with `flags` held, as a CGEvent.
    @MainActor private static func moveMouse(to point: CGPoint, flags: CGEventFlags = []) {
        let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)
        event?.flags = flags
        event?.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.3)
    }
}
