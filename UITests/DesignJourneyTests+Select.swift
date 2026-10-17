// DesignJourneyTests+Select.swift: J5 and J6, several layers as one
// (packet docs/blueprints/design/features/select-several.md, Journey steps,
// SS-a, S-7). On `cards` at 1024 × 768, live services, the Move tool.
// J5: a marquee on Desktop from page (80, 80) to (520, 240) selects A and B
// ("2 Layers" in the status bar); dragging A 40 right moves both ("Undo Move");
// the box's bottom-right handle out 20 resizes both ("Undo Resize"); ⇧→
// ("Undo Nudge"); ⌫ removes both rows ("Undo Delete"); ⌘Z brings them back;
// a marquee over only Locked and Hidden selects nothing. J6: a marquee selects
// A, B and C; the inspector's Align Top ("Undo Align Top"); Object >
// Distribute Horizontally ("Undo Distribute Horizontally"); a marquee over A
// and B: Distribute is disabled in the inspector and the Object menu.
// Page points map to the screen through the artboard (`suite.canvas.artboard`,
// the page's rectangle at the current zoom, #2349): its corner plus the point
// times its width over 1440. Until #2463 routes the canvas keys to the
// several-layer nudge and delete, ⇧→ and ⌫ change nothing on a multi-selection;
// J5 then checks the empty marquee and skips naming #2463, and any other wrong
// step name fails.
import XCTest

final class DesignSelectJourneyTests: XCTestCase {
    static let arguments = ["-DesignFixture", "cards", "-SuiteWindowSize", "1024x768"]
    /// The page's width in `cards` (DesignFixtures.cards), which sets the artboard's scale.
    static let pageWidth = 1440.0
    static let artboard = "suite.canvas.artboard", status = "design.status.selection"
    /// A's and B's rows in Layers (DesignFixtures.cards).
    static let rowA = "design.layer.node-2", rowB = "design.layer.node-3"
    /// DesignControlID.align(.top) and .distribute(.horizontal).
    static let alignTop = "design.align.top", distribute = "design.distribute.horizontal"
    static let distributeTitle = "Distribute Horizontally"

    /// J5: a marquee picks A and B, which then move, resize, nudge and delete as one step each.
    @MainActor func testMarqueeMoveResizeSeveral() throws {
        let design = open()
        let undo = design.element("design.bar.undo")

        // 1. Marquee from (80, 80) to (520, 240) on Desktop: A and B, nothing else.
        drag(design, from: (80, 80), to: (520, 240))
        expectCount(design, "2 Layers", after: "the marquee over A and B")
        design.shot("select-marquee-two")

        // 2. Drag A (100, 100, 100, 80) by its middle 40 right: both move, one Move step.
        drag(design, from: (150, 140), to: (190, 140))
        XCTAssert(Self.waitForLabel(undo, "Undo Move"), "dragging A made no Move step (Undo reads \(undo.label))")
        expectCount(design, "2 Layers", after: "the move")
        design.shot("select-moved")

        // 3. The box is now (140, 100)-(500, 220): its bottom-right handle out 20 resizes both.
        drag(design, from: (500, 220), to: (520, 220))
        XCTAssert(Self.waitForLabel(undo, "Undo Resize"), "the box's handle made no Resize step (Undo reads \(undo.label))")
        design.shot("select-resized")

        // 4. ⇧→ nudges both 10 right: one Nudge step.
        design.press(.rightArrow, .shift)
        if !Self.waitForLabel(undo, "Undo Nudge"), undo.label == "Undo Resize" {
            try skipOnKeys(design, "⇧→ made no step on two layers")
        }
        XCTAssertEqual(undo.label, "Undo Nudge", "⇧→ made the wrong step")
        design.shot("select-nudged")

        // 5. ⌫ deletes both: one Delete step, and A's and B's rows go.
        design.press(.delete)
        if !Self.waitForLabel(undo, "Undo Delete"), undo.label == "Undo Nudge" {
            try skipOnKeys(design, "⌫ made no step on two layers")
        }
        XCTAssertEqual(undo.label, "Undo Delete", "⌫ made the wrong step")
        XCTAssert(Self.waitUntil { !row(design, Self.rowA).exists && !row(design, Self.rowB).exists },
                  "⌫ left A's or B's row in Layers")
        design.shot("select-deleted")

        // 6. ⌘Z takes back the one Delete step: both rows return, and Undo names the Nudge.
        design.press(character: "z", .command)
        XCTAssert(Self.waitUntil { row(design, Self.rowA).exists && row(design, Self.rowB).exists },
                  "⌘Z didn't bring back both A and B")
        XCTAssert(Self.waitForLabel(undo, "Undo Nudge"), "⌘Z took back more than Delete (Undo reads \(undo.label))")
        design.shot("select-undone")

        // 7. A marquee over only Locked and Hidden selects nothing.
        expectEmptyMarquee(design)
    }

    /// J6: three layers align to the top and distribute; two can't distribute.
    @MainActor func testAlignAndDistributeSeveral() {
        let design = open()
        let undo = design.element("design.bar.undo")

        // 1. Marquee from (80, 80) to (820, 240): A, B and C (Title sits above at y 40-72).
        drag(design, from: (80, 80), to: (820, 240))
        expectCount(design, "3 Layers", after: "the marquee over A, B and C")

        // 2. The inspector's Align Top: one Align Top step.
        let top = control(design, Self.alignTop)
        XCTAssert(top.waitForExistence(timeout: 5), "no Align Top in the inspector (\(Self.alignTop))")
        top.click()
        XCTAssert(Self.waitForLabel(undo, "Undo Align Top"), "Align Top made no step (Undo reads \(undo.label))")
        design.shot("select-aligned-top")

        // 3. Object > Distribute Horizontally: B moves to equal gaps, one step.
        let item = objectItem(design, Self.distributeTitle)
        XCTAssert(item.waitForExistence(timeout: 5), "no Object > \(Self.distributeTitle)")
        XCTAssert(item.isEnabled, "Object > \(Self.distributeTitle) is disabled with three layers")
        item.click()
        XCTAssert(Self.waitForLabel(undo, "Undo \(Self.distributeTitle)"),
                  "Distribute made no step (Undo reads \(undo.label))")
        design.shot("select-distributed")

        // 4. A (100-200) and B (350-550) now share y 100-180: a marquee from below-left picks just them.
        drag(design, from: (60, 260), to: (600, 90))
        expectCount(design, "2 Layers", after: "the marquee over A and B")
        let button = control(design, Self.distribute)
        XCTAssert(button.waitForExistence(timeout: 5), "no Distribute in the inspector (\(Self.distribute))")
        XCTAssertFalse(button.isEnabled, "Distribute is enabled with two layers")
        let menuItem = objectItem(design, Self.distributeTitle)
        XCTAssert(menuItem.waitForExistence(timeout: 5), "no Object > \(Self.distributeTitle)")
        XCTAssertFalse(menuItem.isEnabled, "Object > \(Self.distributeTitle) is enabled with two layers")
        design.shot("select-distribute-off")
        design.press(.escape)
    }

    /// Launches `cards` and waits for its artboard.
    @MainActor private func open() -> Journey {
        let design = Journey("Design", self, arguments: Self.arguments)
        XCTAssert(design.app.windows.firstMatch.waitForExistence(timeout: 30), "no window opened")
        XCTAssert(design.element(Self.artboard).waitForExistence(timeout: 10), "cards showed no page (\(Self.artboard))")
        return design
    }

    /// The trailing empty-marquee check, then a skip naming #2463 (the canvas keys miss several layers).
    @MainActor private func skipOnKeys(_ design: Journey, _ what: String) throws {
        design.shot("select-keys-missing")
        expectEmptyMarquee(design)
        throw XCTSkip("#2463: \(what); the canvas keys still send the one-layer nudge and delete")
    }

    /// Marquee (380, 580)-(720, 720) on Desktop touches only Locked and Hidden: the selection is empty.
    @MainActor private func expectEmptyMarquee(_ design: Journey) {
        drag(design, from: (380, 580), to: (720, 720))
        let count = design.element(Self.status)
        XCTAssert(Self.waitUntil { !count.exists }, "the marquee over Locked and Hidden selected \(Self.text(count))")
        design.shot("select-marquee-empty")
    }

    /// The status bar's selection count reads `expected`.
    @MainActor private func expectCount(_ design: Journey, _ expected: String, after step: String) {
        let count = design.element(Self.status)
        XCTAssert(Self.waitUntil { count.exists && Self.text(count) == expected },
                  "after \(step) the selection reads \(count.exists ? Self.text(count) : "nothing"), not \(expected)")
    }

    /// Opens the Object menu and returns its item `title`.
    @MainActor private func objectItem(_ design: Journey, _ title: String) -> XCUIElement {
        design.app.menuBars.firstMatch.menuBarItems["Object"].click()
        return design.app.menuBars.firstMatch.menuItems[title].firstMatch
    }

    /// The Layers row with the id `identifier`.
    @MainActor private func row(_ design: Journey, _ identifier: String) -> XCUIElement {
        design.element("suite.sidebar").descendants(matching: .any)[identifier].firstMatch
    }

    /// The inspector's control with the id `identifier`.
    @MainActor private func control(_ design: Journey, _ identifier: String) -> XCUIElement {
        design.element("suite.inspector").descendants(matching: .any)[identifier].firstMatch
    }

    /// Presses the page point `start` and drags to the page point `end`.
    @MainActor private func drag(_ design: Journey, from start: (Double, Double), to end: (Double, Double)) {
        let artboard = design.element(Self.artboard)
        point(start, on: artboard).press(forDuration: 0.1, thenDragTo: point(end, on: artboard))
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
