// DesignJourneyTests+Layout.swift: Design's window at every width (design-window
// DW-c, D0-7b; blueprint design.md 7.3). `testLayoutAtWidths` launches on
// `-DesignFixture cards` with `-DesignWindowSize <w>x<h>` (the content size,
// which the window floors at its own minimum), opens the Desktop frame's row
// (a document opens with its rows collapsed, #3044), selects A from Layers, shoots
// "layout-<w>x<h>" and asserts 7.3's six rules from element frames, to 0.5 pt:
// 1. sidebar, canvas and panel meet with no gap or overlap (a split view
//    divider between two columns is where they meet), the panel is 280 pt
//    (its column less SuiteWindow's 12 pt padding either side) and the canvas
//    at least 440 pt (SuiteSize.contentMinimum);
// 2. the eight toolbar items are inside the window, hittable (so none went to
//    the overflow), titled and clear of one another;
// 3. the Frame fields and the Fill well start at the X field's leading x, and
//    so does the locked hint, on "Locked" (#276). The bar rows (Opacity,
//    Radius, Stroke Width) carry their label inside the bar, so they span the
//    row and have no value column; A has no Text section;
// 4. every Layers row's eye shares one x, and every lock one, at each depth
//    shown (a group's row reads as one checkbox, so its toggles don't show);
// 5. the status texts sit on one line, clear of one another; the selection,
//    save, tool and page-size chips keep their 1024 widths at every size (at
//    880 only the message may shorten; from 1280 the message keeps it too);
// 6. `shot` audits each size, and the design line's `overlap` and `offscreen`
//    baselines are 0 (UITests/audit-baseline.json), so either fails the shot.
// 1024 × 720 runs first, as the widths the other sizes are held to; 880 × 560
// next; both run on the 1024 × 768 runner. 1280 × 800, 1440 × 900 and
// 1920 × 1080 throw XCTSkip once the display's visible frame is smaller.
import AppKit
import XCTest

final class DesignLayoutJourneyTests: XCTestCase {
    static let ciSizes: [(width: Double, height: Double)] = [(1024, 720), (880, 560)]
    static let localSizes: [(width: Double, height: Double)] = [(1280, 800), (1440, 900), (1920, 1080)]
    static let tolerance = 0.5
    static let panel = 280.0, panelPadding = 12.0, canvasMinimum = 440.0
    /// Design's narrowest window: the sidebar's ideal 200, the canvas's 440 and the 304 pt inspector column.
    static let windowFloor = 200.0 + canvasMinimum + panel + 2 * panelPadding
    static let bar = ["design.bar.new", "design.bar.open", "design.bar.save", "design.bar.undo",
                      "design.bar.redo", "design.bar.zoom-out", "design.bar.fit", "design.bar.zoom-in"]
    static let fields = ["design.inspector.y", "design.inspector.width", "design.inspector.height"]
    static let chips = ["design.status.selection", "design.status.save", "design.status.tool"]
    /// The `cards` fixture's Desktop frame, the parent of every layer the rules click.
    static let desktopRow = "design.layer.node-1"

    @MainActor func testLayoutAtWidths() throws {
        var widths: [String: Double] = [:]
        for size in Self.ciSizes { check(size, widths: &widths) }
        for size in Self.localSizes {
            let visible = NSScreen.main?.visibleFrame.size ?? .zero
            if Double(visible.width) < size.width || Double(visible.height) < size.height {
                throw XCTSkip("the display's visible frame (\(visible)) is smaller than \(size); 7.3 runs it locally")
            }
            check(size, widths: &widths)
        }
    }

    /// One size: launch, select A, shoot, then the six rules; "Locked" last, as it moves the selection.
    @MainActor private func check(_ size: (width: Double, height: Double), widths: inout [String: Double]) {
        let label = "\(Int(size.width))x\(Int(size.height))"
        let design = Journey("Design", self, arguments: ["-DesignFixture", "cards", "-DesignWindowSize", label])
        let window = design.app.windows.firstMatch
        XCTAssert(window.waitForExistence(timeout: 30), "no window opened at \(label)")
        XCTAssert(design.element("suite.canvas").waitForExistence(timeout: 10), "cards showed no page at \(label)")
        let expected = max(size.width, Self.windowFloor)
        XCTAssert(Self.waitForWidth(window, expected), "the window at \(label) is \(window.frame.width) pt wide, not \(expected)")
        select("node-2", in: design)
        XCTAssertEqual(Self.text(design.element("design.status.selection")), "1 Layer", "selecting A at \(label)")
        design.shot("layout-\(label)")
        expectColumns(design, label)
        expectBar(design, label)
        expectValueColumn(design, label)
        expectToggles(design, label)
        expectStatus(design, label, width: size.width, widths: &widths)
        select("node-9", in: design)
        let hint = design.element("design.inspector.hint")
        XCTAssert(hint.waitForExistence(timeout: 5), "selecting Locked at \(label) shows no hint (design.inspector.hint)")
        let column = design.element("design.inspector.x").frame.minX
        XCTAssertEqual(hint.frame.minX, column, accuracy: Self.tolerance, "the locked hint at \(label) isn't in the value column")
    }

    /// Clicks the Layers row of `node`, as a person picks a layer: Desktop's row opened first, as
    /// `cards` opens with every row collapsed and A and Locked sit inside it (#3044).
    @MainActor private func select(_ node: String, in design: Journey) {
        design.expandDesignLayer(Self.desktopRow)
        design.clickDesignLayer("design.layer.\(node)")
        XCTAssert(design.element("design.inspector.x").waitForExistence(timeout: 5), "selecting \(node) showed no Frame fields")
    }

    /// Rule 1: the three columns side by side, the 280 pt panel and the 440 pt canvas.
    @MainActor private func expectColumns(_ design: Journey, _ label: String) {
        guard let sidebar = design.regionFrame("suite.sidebar"), let canvas = design.regionFrame("suite.viewport"),
              let column = design.regionFrame("suite.inspector")
        else { return XCTFail("a column is missing at \(label)") }
        let dividers = design.app.windows.firstMatch.splitters.allElementsBoundByIndex.map(\.frame)
        for (left, right, names) in [(sidebar, canvas, "sidebar and canvas"), (canvas, column, "canvas and panel")] {
            XCTAssert(Self.meet(left, right, dividers), "\(names) don't meet at \(label): \(left.maxX) to \(right.minX)")
        }
        let panel = Double(column.width) - 2 * Self.panelPadding
        XCTAssertEqual(panel, Self.panel, accuracy: Self.tolerance, "the panel at \(label) is \(panel) pt, not 280")
        XCTAssertGreaterThanOrEqual(Double(canvas.width), Self.canvasMinimum - Self.tolerance, "the canvas at \(label) is under 440 pt")
    }

    /// Rule 2: every toolbar item inside the window, hittable, titled, and clear of the others.
    @MainActor private func expectBar(_ design: Journey, _ label: String) {
        let window = design.app.windows.firstMatch.frame
        var frames: [(String, CGRect)] = []
        for id in Self.bar {
            let item = design.element(id)
            XCTAssert(item.exists && item.isHittable, "\(id) at \(label) isn't hittable (cut off or in the overflow)")
            XCTAssert(window.insetBy(dx: -Self.tolerance, dy: -Self.tolerance).contains(item.frame), "\(id) runs out of the window at \(label)")
            XCTAssertFalse(item.label.isEmpty, "\(id) at \(label) has no title")
            for (other, frame) in frames where Self.overlaps(item.frame, frame) {
                XCTFail("\(id) overlaps \(other) at \(label)")
            }
            frames.append((id, item.frame))
        }
    }

    /// Rule 3: Y, W, H and the Fill well start where X does.
    @MainActor private func expectValueColumn(_ design: Journey, _ label: String) {
        let column = design.element("design.inspector.x").frame.minX
        for id in Self.fields {
            let field = design.element(id)
            XCTAssert(field.exists, "no \(id) at \(label)")
            XCTAssertEqual(field.frame.minX, column, accuracy: Self.tolerance, "\(id) at \(label) leaves the value column")
        }
        let well = design.element("suite.inspector").descendants(matching: .colorWell).firstMatch
        XCTAssert(well.exists, "the Fill section shows no color well at \(label)")
        XCTAssertEqual(well.frame.minX, column, accuracy: Self.tolerance, "the Fill well at \(label) leaves the value column")
    }

    /// Rule 4: one x for every eye and one for every lock in Layers.
    @MainActor private func expectToggles(_ design: Journey, _ label: String) {
        let rows = design.element("suite.sidebar").descendants(matching: .any)
        for flag in ["hidden", "locked"] {
            let predicate = NSPredicate(format: "identifier BEGINSWITH 'suite.sidebar.node-' AND identifier ENDSWITH %@", "." + flag)
            let xs = rows.matching(predicate).allElementsBoundByIndex.filter(\.exists).map { Double($0.frame.minX) }
            XCTAssertGreaterThanOrEqual(xs.count, 2, "Layers shows under two \(flag) toggles at \(label)")
            let spread = (xs.max() ?? 0) - (xs.min() ?? 0)
            XCTAssertLessThanOrEqual(spread, Self.tolerance, "the \(flag) toggles at \(label) sit \(spread) pt apart: \(xs)")
        }
    }

    /// Rule 5: the status texts on one line, clear of one another; the fixed chips keep their 1024 widths.
    @MainActor private func expectStatus(_ design: Journey, _ label: String, width: Double, widths: inout [String: Double]) {
        let texts = design.element("suite.status").staticTexts.allElementsBoundByIndex.filter { $0.exists && !$0.frame.isEmpty }
        XCTAssertGreaterThanOrEqual(texts.count, 3, "the status line at \(label) shows under three texts")
        let mids = texts.map { Double($0.frame.midY) }
        XCTAssertLessThanOrEqual((mids.max() ?? 0) - (mids.min() ?? 0), Self.tolerance, "the status line at \(label) wraps: \(mids)")
        for (index, text) in texts.enumerated() {
            for other in texts.prefix(index) where Self.overlaps(text.frame, other.frame) {
                XCTFail("the status texts '\(Self.text(text))' and '\(Self.text(other))' overlap at \(label)")
            }
        }
        let page = design.element("suite.status").staticTexts
            .matching(NSPredicate(format: "label CONTAINS ' × ' OR value CONTAINS ' × '")).firstMatch
        var chips = Dictionary(uniqueKeysWithValues: Self.chips.map { ($0, design.element($0)) })
        chips["page size"] = page
        if width > 1024 { chips["design.status.note"] = design.element("design.status.note") }
        for (name, chip) in chips where chip.exists {
            let measured = Double(chip.frame.width)
            guard let reference = widths[name] else {
                if width == 1024 { widths[name] = measured }
                continue
            }
            XCTAssertEqual(measured, reference, accuracy: Self.tolerance, "\(name) at \(label) is \(measured) pt, \(reference) at 1024")
        }
    }

    /// Whether two neighbouring columns meet: edge to edge, or with only a split view divider between them.
    private static func meet(_ left: CGRect, _ right: CGRect, _ dividers: [CGRect]) -> Bool {
        if abs(Double(right.minX - left.maxX)) <= tolerance { return true }
        return dividers.contains {
            abs(Double($0.minX - left.maxX)) <= tolerance && abs(Double(right.minX - $0.maxX)) <= tolerance
        }
    }

    /// Whether two frames share more than the tolerance both ways.
    private static func overlaps(_ first: CGRect, _ second: CGRect) -> Bool {
        let shared = first.intersection(second)
        return !shared.isNull && Double(shared.width) > tolerance && Double(shared.height) > tolerance
    }

    /// Whether `window` reads `width` wide within a point inside five seconds
    /// (the window takes `-DesignWindowSize` on the turn after it opens).
    @MainActor private static func waitForWidth(_ window: XCUIElement, _ width: Double) -> Bool {
        for _ in 0..<20 {
            if abs(Double(window.frame.width) - width) <= 1 { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return abs(Double(window.frame.width) - width) <= 1
    }

    /// What a text reads: its label, or its value where macOS puts a plain Text's words.
    @MainActor private static func text(_ element: XCUIElement) -> String {
        element.label.isEmpty ? (element.value as? String ?? "") : element.label
    }
}
