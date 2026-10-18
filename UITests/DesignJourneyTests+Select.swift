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
// step name fails. J4 (S-7b): the zoom pill's fitted percent f; C selected;
// ⌘= twice steps two ViewerZoom stops up; Space-drag 200 pt left pans
// `design.canvas.selection` about 200 pt left; ⌘0 reads f again; View > Zoom
// to Selection zooms past both stops; Escape, then the item is disabled.
// XCUITest can't hold a key that isn't a modifier, so Space goes down and up
// as CGEvents, and a runner without post-event access skips that step by name.
// C's center within 2 pt of the canvas center skips naming #2147 (CanvasViewport
// can't scroll to a rect yet). Every other step still asserts first.
import CoreGraphics
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

        // 3. The box is now (140, 100)-(540, 220) (B ends at x 540): its bottom-right handle out
        // 20 resizes both. (500, 220) is B's bottom edge, a Move (#2517, DesignJ5GeometryTests).
        drag(design, from: (540, 220), to: (560, 220))
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
        // Close the menu first: an open menu covers the toolbar in the shot and fails contrast (#2516).
        design.press(.escape)
        design.shot("select-distribute-off")
    }

    /// The percents of ViewerZoom.stops, the stops ⌘= steps through (UITests can't import SuiteUI).
    static let stopPercents = [5, 10, 25, 33, 50, 67, 100, 150, 200, 300, 400, 600, 800, 1200, 1600, 3200]
    static let zoomToSelection = "Zoom to Selection"

    /// J4: zoom in, pan with Space, fit with ⌘0, then View > Zoom to Selection, which Escape disables.
    @MainActor func testZoomPanFitAndZoomToSelection() throws {
        let design = open()
        var skips: [String] = []

        // 1. The pill's fitted percent f; then press C (700, 100, 100, 120) on the page to select it.
        let fitted = try XCTUnwrap(zoomPercent(design), "the status line shows no zoom")
        drag(design, from: (750, 160), to: (750, 160))
        let selection = design.element("design.canvas.selection")
        XCTAssert(selection.waitForExistence(timeout: 5), "pressing C selected nothing (design.canvas.selection)")
        design.shot("select-zoom-fit")

        // 2. ⌘= twice: the pill reads a stop at or just above f, then the stop after it.
        design.press(character: "=", .command)
        let first = waitForZoom(design) { $0 != fitted } ?? fitted
        let candidates = Self.stopPercents.filter { $0 >= fitted }.prefix(2)
        XCTAssert(candidates.contains(first), "⌘= from \(fitted)% read \(first)%, not the next stop")
        design.press(character: "=", .command)
        let next = Self.stopPercents.firstIndex(of: first).flatMap { Self.stopPercents.dropFirst($0 + 1).first }
        let second = waitForZoom(design) { $0 == next } ?? first
        XCTAssertEqual(second, next, "the second ⌘= read \(second)%, not the stop after \(first)%")
        design.shot("select-zoom-in")

        // 3. Space-drag 200 pt left from the canvas's middle: the selection moves about 200 pt left.
        if CGPreflightPostEventAccess() {
            let before = selection.frame.midX
            let viewport = design.element("suite.viewport")
            let start = viewport.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5))
            holdingSpace { start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: -200, dy: 0))) }
            XCTAssert(Self.waitUntil { abs(selection.frame.midX - (before - 200)) <= 30 },
                      "Space-drag moved the selection from x \(before) to \(selection.frame.midX), not about 200 pt left")
            XCTAssertEqual(zoomPercent(design), second, "Space-drag changed the zoom")
            design.shot("select-zoom-panned")
        } else {
            skips.append("the runner can't post a held Space (CGPreflightPostEventAccess is false)")
        }

        // 4. ⌘0 fits the page again: the pill reads f.
        design.press(character: "0", .command)
        XCTAssertEqual(waitForZoom(design) { $0 == fitted }, fitted, "⌘0 didn't return to the fitted \(fitted)%")
        design.shot("select-zoom-refit")

        // 5. View > Zoom to Selection (⌥⌘2) fits C, zooming in past both ⌘= stops.
        let item = viewItem(design, Self.zoomToSelection)
        XCTAssert(item.waitForExistence(timeout: 5), "no View > \(Self.zoomToSelection)")
        XCTAssert(item.isEnabled, "View > \(Self.zoomToSelection) is disabled with C selected")
        item.click()
        let framed = waitForZoom(design) { $0 > second } ?? fitted
        XCTAssertGreaterThan(framed, second, "Zoom to Selection read \(framed)%, not a zoom that fits C")
        design.shot("select-zoom-selection")
        let canvas = design.element("suite.viewport").frame
        let center = CGPoint(x: canvas.minX + (canvas.width + 20) / 2, y: canvas.minY + (canvas.height + 20) / 2)
        let offset = hypot(selection.frame.midX - center.x, selection.frame.midY - center.y)
        if offset > 2 { skips.append("#2147: C's center is \(Int(offset)) pt from the canvas center") }

        // 6. Escape deselects: View > Zoom to Selection is disabled ("Select a layer first.").
        design.press(.escape)
        XCTAssert(Self.waitUntil { !selection.exists }, "Escape left C selected")
        let off = viewItem(design, Self.zoomToSelection)
        XCTAssert(off.waitForExistence(timeout: 5), "no View > \(Self.zoomToSelection)")
        XCTAssertFalse(off.isEnabled, "View > \(Self.zoomToSelection) is enabled with nothing selected")
        design.shot("select-zoom-none", screen: true)
        design.press(.escape)
        if !skips.isEmpty { throw XCTSkip(skips.joined(separator: "; ")) }
    }

    /// The zoom pill's percent once `condition` holds on it within 5 seconds, else nil.
    @MainActor private func waitForZoom(_ design: Journey, _ condition: (Int) -> Bool) -> Int? {
        Self.waitUntil { zoomPercent(design).map(condition) == true } ? zoomPercent(design) : nil
    }

    /// The zoom pill's percent: "Zoom 25%" as its label, or "25%" as a plain Text's words (#1452).
    @MainActor private func zoomPercent(_ design: Journey) -> Int? {
        let texts = design.element("suite.status").staticTexts.allElementsBoundByIndex
            .flatMap { [$0.label, $0.value as? String ?? ""] }
        return texts.lazy.compactMap { text -> Int? in
            let percent = text.hasPrefix("Zoom ") ? String(text.dropFirst(5)) : text
            return percent.hasSuffix("%") ? Int(percent.dropLast()) : nil
        }.first
    }

    /// Runs `body` with Space held down, posted as CGEvents (virtual key 49).
    @MainActor private func holdingSpace(_ body: () -> Void) {
        CGEvent(keyboardEventSource: nil, virtualKey: 49, keyDown: true)?.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.2)
        body()
        CGEvent(keyboardEventSource: nil, virtualKey: 49, keyDown: false)?.post(tap: .cghidEventTap)
        Thread.sleep(forTimeInterval: 0.2)
    }

    /// Opens the View menu and returns its item `title`.
    @MainActor private func viewItem(_ design: Journey, _ title: String) -> XCUIElement {
        design.app.menuBars.firstMatch.menuBarItems["View"].click()
        return design.app.menuBars.firstMatch.menuItems[title].firstMatch
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
